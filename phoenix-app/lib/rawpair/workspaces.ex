defmodule RawPair.Workspaces do
  import Ecto.Query
  alias RawPair.{Repo, Runtime, Accounts}
  alias RawPair.Workspaces.Workspace

  def list_workspaces(user) do
    Repo.all(
      from w in Workspace,
        join: m in "workspace_memberships",
        on: m.workspace_id == w.id,
        where: m.user_id == ^user.id,
        order_by: w.name,
        select: w
    )
  end

  def get_workspace!(id), do: Repo.get!(Workspace, id)
  def get_workspace_by_slug!(slug), do: Repo.get_by!(Workspace, slug: slug)
  def get_by_runtime(id), do: Repo.get_by(Workspace, runtime_id: id)

  def role(user, workspace) when not is_nil(user) do
    Repo.one(
      from m in "workspace_memberships",
        where: m.workspace_id == ^workspace.id and m.user_id == ^user.id,
        select: m.role
    )
  end

  def role(_, _), do: nil

  def permitted?(user, workspace, permission \\ :member) do
    role = role(user, workspace)
    if permission == :owner, do: role == "owner", else: role in ["owner", "member"]
  end

  def authorize!(user, workspace, permission \\ :member) do
    if permitted?(user, workspace, permission),
      do: workspace,
      else: raise(Ecto.NoResultsError, queryable: Workspace)
  end

  def get_authorized!(user, id, permission \\ :member),
    do: authorize!(user, get_workspace!(id), permission)

  def by_slug_authorized!(user, slug, permission \\ :member),
    do: authorize!(user, get_workspace_by_slug!(slug), permission)

  def create_workspace(user, attrs) do
    attrs =
      attrs
      |> Map.drop(["runtime_id", "status", "workspace_port", "postgres_port"])
      |> Map.put(
        "runtime_id",
        "ws-" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
      )

    changeset = Workspace.changeset(%Workspace{}, attrs) |> validate_enabled()

    result =
      Repo.transaction(fn ->
        workspace =
          case Repo.insert(changeset) do
            {:ok, workspace} -> workspace
            {:error, changeset} -> Repo.rollback(changeset)
          end

        Repo.insert_all("workspace_memberships", [
          %{workspace_id: workspace.id, user_id: user.id, role: "owner"}
        ])

        workspace
      end)

    case result do
      {:ok, workspace} ->
        case Runtime.configure(workspace) do
          {:ok, _} -> {:ok, workspace}
          {:error, _reason} -> update_workspace(workspace, %{status: :failed})
        end

      error ->
        error
    end
  end

  # Internal record updates used by the existing Docker backend.
  def update_workspace(workspace, attrs),
    do: workspace |> Workspace.changeset(attrs) |> Repo.update()

  def change_workspace(workspace, attrs \\ %{}), do: Workspace.changeset(workspace, attrs)

  def configure(user, workspace, attrs) do
    authorize!(user, workspace, :owner)

    changeset =
      Workspace.changeset(
        workspace,
        Map.drop(attrs, ["runtime_id", "status", "workspace_port", "postgres_port"])
      )
      |> validate_enabled()

    changeset =
      Enum.reduce([:backend, :host_slot, :slug], changeset, fn field, changeset ->
        if Ecto.Changeset.get_field(changeset, field) != Map.get(workspace, field),
          do: Ecto.Changeset.add_error(changeset, field, "cannot change after creation"),
          else: changeset
      end)

    Repo.transaction(fn ->
      candidate =
        case Repo.update(changeset) do
          {:ok, candidate} -> candidate
          {:error, changeset} -> Repo.rollback(changeset)
        end

      case Runtime.configure(candidate) do
        {:ok, _} ->
          candidate

        {:error, reason} ->
          Repo.rollback(Ecto.Changeset.add_error(changeset, :host_slot, inspect(reason)))
      end
    end)
  end

  def transition(user, workspace, action) when action in [:start, :stop] do
    authorize!(user, workspace)
    result = apply(Runtime, action, [workspace])

    case result do
      {:ok, _} ->
        status = if action == :start, do: :running, else: :stopped

        update_workspace(Repo.get!(Workspace, workspace.id), %{
          status: status,
          last_active_at: Accounts.now()
        })

      error ->
        error
    end
  end

  def remove(user, workspace) do
    authorize!(user, workspace, :owner)

    with {:ok, _} <- Runtime.remove(workspace) do
      result = Repo.delete(workspace)
      if match?({:ok, _}, result), do: purge_collaboration(workspace)
      result
    end
  end

  def delete_files(user, %{backend: :host} = workspace, confirmation) do
    authorize!(user, workspace, :owner)

    with {:ok, value} <- RawPair.Runtime.Orqos.delete_files(workspace, confirmation) do
      Repo.update_all(from(w in Workspace, where: w.id == ^workspace.id),
        inc: [collaboration_version: 1]
      )

      purge_collaboration(workspace)
      {:ok, value}
    end
  end

  def delete_files(_, _, _),
    do: {:error, "Container volume deletion remains an operator operation"}

  def members(workspace) do
    Repo.all(
      from m in "workspace_memberships",
        join: u in Accounts.User,
        on: u.id == m.user_id,
        where: m.workspace_id == ^workspace.id,
        select: %{id: u.id, username: u.username, role: m.role}
    )
  end

  def add_member(user, workspace, username, role) when role in ["member", "owner"] do
    authorize!(user, workspace, :owner)

    case Accounts.by_username(username) do
      nil ->
        {:error, "No account with that username"}

      member ->
        Repo.transaction(fn ->
          Repo.one!(from w in Workspace, where: w.id == ^workspace.id, lock: "FOR UPDATE")
          previous = role(member, workspace)

          owners =
            Repo.aggregate(
              from(m in "workspace_memberships",
                where: m.workspace_id == ^workspace.id and m.role == "owner"
              ),
              :count
            )

          if previous == "owner" and role == "member" and owners == 1,
            do: Repo.rollback("A workspace needs at least one owner")

          Repo.insert_all(
            "workspace_memberships",
            [%{workspace_id: workspace.id, user_id: member.id, role: role}],
            on_conflict: [set: [role: role]],
            conflict_target: [:workspace_id, :user_id]
          )

          member
        end)
    end
  end

  def remove_member(user, workspace, member_id) do
    authorize!(user, workspace, :owner)

    Repo.transaction(fn ->
      Repo.one!(from w in Workspace, where: w.id == ^workspace.id, lock: "FOR UPDATE")

      owners =
        Repo.all(
          from m in "workspace_memberships",
            where: m.workspace_id == ^workspace.id and m.role == "owner",
            select: m.user_id
        )

      member_id = String.to_integer(to_string(member_id))
      if owners == [member_id], do: Repo.rollback("A workspace needs at least one owner")

      Repo.delete_all(
        from m in "workspace_memberships",
          where: m.workspace_id == ^workspace.id and m.user_id == ^member_id
      )
    end)
  end

  def adopt_legacy_workspaces(username) do
    user = Accounts.by_username(username) || raise "Unknown account"

    Repo.all(Workspace)
    |> Enum.each(fn workspace ->
      if members(workspace) == [],
        do:
          Repo.insert_all("workspace_memberships", [
            %{workspace_id: workspace.id, user_id: user.id, role: "owner"}
          ])
    end)

    :ok
  end

  defp purge_collaboration(workspace) do
    url = Application.get_env(:rawpair, :collaboration_url, "http://127.0.0.1:1234")
    secret = Application.get_env(:rawpair, :collaboration_token, "")

    Finch.build(:delete, "#{url}/internal/workspaces/#{workspace.id}/documents", [
      {"authorization", "Bearer " <> secret}
    ])
    |> Finch.request(RawPair.Finch, receive_timeout: 5000)
  end

  defp validate_enabled(changeset) do
    if Ecto.Changeset.get_field(changeset, :backend) in Application.get_env(:rawpair, :backends, [
         :docker
       ]),
       do: changeset,
       else: Ecto.Changeset.add_error(changeset, :backend, "is not enabled on this deployment")
  end
end

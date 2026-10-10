defmodule RawPairWeb.NativeAccessTest do
  use RawPairWeb.ConnCase
  import RawPair.NativeFixtures
  alias RawPair.{Accounts, Applications, Repo, Workspaces}

  setup do
    Application.put_env(:rawpair, :gateway_token, String.duplicate("g", 64))
    Application.put_env(:rawpair, :collaboration_token, String.duplicate("c", 64))
    Application.put_env(:rawpair, :preview_domain, "apps.rawpair.test")
    owner = user()
    project = workspace(owner)
    member = user()
    Workspaces.add_member(owner, project, member.username, "member")
    outsider = user()

    app =
      Repo.insert!(%Workspaces.Application{
        workspace_id: project.id,
        name: "web",
        port: 3000,
        hostname_id: String.duplicate("a", 24),
        public: false
      })

    %{owner: owner, project: project, member: member, outsider: outsider, app: app}
  end

  test "files and collaboration tickets reject nonmembers", c do
    conn = init_test_session(c.conn, session_token: Accounts.create_session(c.outsider))
    assert_error_sent 404, fn -> get(conn, "/api/workspaces/#{c.project.slug}/files") end

    assert_error_sent 404, fn ->
      get(conn, "/api/workspaces/#{c.project.slug}/collaboration?path=main.ex")
    end
  end

  test "collaboration tickets bind workspace, file and live login", c do
    token = Accounts.create_session(c.member)
    conn = init_test_session(c.conn, session_token: token)

    data =
      get(conn, "/api/workspaces/#{c.project.slug}/collaboration?path=src/main.ex")
      |> json_response(200)

    assert [c.project.id, "src/main.ex", 0] ==
             Jason.decode!(Base.url_decode64!(data["document"], padding: false))

    auth = build_conn() |> put_req_header("authorization", "Bearer " <> String.duplicate("c", 64))

    assert json_response(
             post(auth, "/internal/collaboration/authorize", %{
               ticket: data["ticket"],
               document: data["document"],
               connected: true
             }),
             200
           )["authorized"]

    wrong =
      build_conn() |> put_req_header("authorization", "Bearer " <> String.duplicate("c", 64))

    assert json_response(
             post(wrong, "/internal/collaboration/authorize", %{
               ticket: data["ticket"],
               document: "other",
               connected: true
             }),
             403
           )["error"]

    Accounts.delete_session(token)

    revoked =
      build_conn() |> put_req_header("authorization", "Bearer " <> String.duplicate("c", 64))

    assert json_response(
             post(revoked, "/internal/collaboration/authorize", %{
               ticket: data["ticket"],
               document: data["document"],
               connected: true
             }),
             403
           )["error"]
  end

  test "private previews exchange single-use grants for separate host-only cookies", c do
    token = Accounts.create_session(c.member)
    browser = init_test_session(c.conn, session_token: token)
    host = Applications.host(c.app)
    target = get(browser, "/previews/#{host}") |> redirected_to()
    assert String.starts_with?(target, "https://#{host}/_rawpair/claim?token=")
    grant = URI.parse(target).query |> URI.decode_query() |> Map.fetch!("token")

    gateway = fn ->
      build_conn()
      |> put_req_header("x-rawpair-gateway", String.duplicate("g", 64))
      |> put_req_header("x-preview-host", host)
    end

    claim = get(gateway.(), "/internal/previews/claim?token=#{grant}")
    assert redirected_to(claim) == "/"
    cookie = claim.resp_cookies["__Host-rawpair_preview"]
    assert cookie.secure and cookie.http_only
    refute Map.has_key?(cookie, :domain)
    assert response(get(gateway.(), "/internal/previews/claim?token=#{grant}"), 403)

    authorized =
      gateway.()
      |> put_req_cookie("__Host-rawpair_preview", cookie.value)
      |> get("/internal/previews/authorize")

    assert response(authorized, 204) == ""

    assert get_resp_header(authorized, "x-orqos-target") == [
             "/host/workspaces/#{c.project.runtime_id}/applications/web/proxy"
           ]

    Accounts.delete_session(token)

    assert response(
             gateway.()
             |> put_req_cookie("__Host-rawpair_preview", cookie.value)
             |> get("/internal/previews/authorize"),
             401
           )
  end

  test "public sharing grants only that app, and only owners can publish", c do
    assert_raise Ecto.NoResultsError, fn ->
      Applications.visibility(c.member, c.project, c.app, true)
    end

    assert {:ok, _} = Applications.visibility(c.owner, c.project, c.app, true)

    gateway = fn ->
      build_conn()
      |> put_req_header("x-rawpair-gateway", String.duplicate("g", 64))
      |> put_req_header("x-preview-host", Applications.host(c.app))
    end

    assert response(get(gateway.(), "/internal/previews/authorize"), 204) == ""
    assert response(get(gateway.(), "/internal/terminal/#{c.project.runtime_id}"), 403)
    assert response(get(build_conn(), "/internal/previews/authorize"), 403)
  end
end

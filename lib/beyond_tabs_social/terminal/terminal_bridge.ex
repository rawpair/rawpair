defmodule BeyondTabsSocial.TerminalBridge do
  use GenServer

  def start_link(slug), do: GenServer.start_link(__MODULE__, slug)

  def send_input(pid, char), do: GenServer.cast(pid, {:input, char})

  def init(slug) do
    container = "workspace-#{slug}"

    port =
      Port.open(
        {:spawn_executable, "/usr/bin/docker"},
        [:binary, :exit_status,
        args: [
          "exec", "-i", container,
          "script", "-qfc", "stty -echo; sh", "/dev/null"
        ]]
      )

      Port.command(port, "export TERM=xterm\n")


    {:ok, %{port: port, slug: slug}}
  end

  def handle_cast({:input, data}, %{port: port} = state) do
    Port.command(port, data)
    {:noreply, state}
  end

  def handle_info({port_id, {:data, output}}, %{port: port_id} = state) do
    BeyondTabsSocialWeb.Endpoint.broadcast("terminal:" <> state.slug, "output", %{data: output})
    {:noreply, state}
  end

  def handle_info({port_id, {:exit_status, _}}, %{port: port_id} = state) do
    {:noreply, state}
  end
end

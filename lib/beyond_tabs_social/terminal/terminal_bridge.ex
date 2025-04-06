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
          "script", "-qc", "sh", "/dev/null"
        ]
        ]
      )

    Port.command(port, "echo Hello from inside\n")
    {:ok, %{port: port, slug: slug, buffer: ""}}
  end

  def handle_cast({:input, char}, %{buffer: buffer, port: port} = state) do
    new_buffer = buffer <> char

    if char in ["\n", "\r"] do
      Port.command(port, new_buffer)
      {:noreply, %{state | buffer: ""}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info({_, {:data, output}}, state) do
    BeyondTabsSocialWeb.Endpoint.broadcast("terminal:" <> state.slug, "output", %{data: output})
    {:noreply, state}
  end

  def handle_info({_, {:exit_status, _}}, state), do: {:noreply, state}
end

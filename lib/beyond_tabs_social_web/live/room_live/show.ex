defmodule BeyondTabsSocialWeb.RoomLive.Show do
  use BeyondTabsSocialWeb, :live_view

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    {:ok,
     socket
     |> assign(:slug, slug)
     |> assign(:page_title, "Room: #{slug}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h1 class="text-xl font-semibold"><%= @page_title %></h1>

      <!-- Video (LiveKit) placeholder -->
      <div id="livekit-video" class="w-full h-[400px] border rounded bg-zinc-900 text-white flex items-center justify-center">
        <p class="text-sm">[ video feed will go here ]</p>
      </div>

      <!-- Monaco Editor placeholder -->
      <div id="monaco-editor"
           phx-hook="EditorHook"
           data-slug={@slug}
           class="w-full h-[600px] border rounded" />
    </div>
    """
  end
end

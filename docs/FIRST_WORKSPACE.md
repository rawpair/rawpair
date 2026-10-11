# Your first shared workspace

Build something small together: serve a page, change it in the shared editor, and see the result through a private HTTPS preview. This walkthrough uses Python already included in a native installation, so you can try the complete flow before choosing a language stack.

## Before you start

Finish [package setup](PACKAGES.md) or [source setup](NATIVE_SETUP.md). You need the login created during setup and a running installation. Package users can check it with:

```sh
sudo rawpair doctor
```

Open the login URL printed by setup. Local mode defaults to `https://rawpair.localhost` in a browser **on the deployment machine**. For someone on another machine, use [remote setup](PACKAGES.md#remote-setup-dns-and-certificates). Accounts are operator-created; there is no public sign-up.

## Create and start a project

1. Log in and choose **New project workspace**.
2. Name it `Hello RawPair`. Select the `host` execution backend and an unused provisioned slot, such as `project-a`. The slot supplies a dedicated account and project directory. Keep CPU, memory and task fields at their defaults for this demo.
3. Choose **Create workspace**, then **Start / reconnect** on its management page.
4. Open **Open editor and shared terminal**. The terminal starts in your project's directory.

Setup prepares two slots, `project-a` and `project-b`. Creating a RawPair workspace assigns a slot; starting it launches the processes. A reused slot retains its previous project files, so use an empty slot for this demo. If both are occupied, the operator can add one with `sudo rawpair workspace add project-c`.

## Run something you can see

Run these commands **inside the workspace terminal**, in a fresh project directory:

```sh
mkdir -p hello-rawpair
cat > hello-rawpair/index.html <<'HTML'
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>Hello from RawPair</title>
<h1>We built this together.</h1>
<p>This page is running in our shared workspace.</p>
</html>
HTML
python3 -m http.server 3000 --bind 127.0.0.1 --directory hello-rawpair
```

Leave the server running. It serves only the demo directory. Closing the browser does not stop it; **Stop workspace** does.

On the workspace's management page, find **Applications**. Enter `web` as the application name and `3000` as the internal HTTP port, then choose **Register private application**. Choose **Check connection** and open the displayed HTTPS URL. You should see “We built this together.”

Use that displayed preview URL rather than `localhost:3000` in your browser. The development server is inside the workspace's own network; RawPair's gateway connects to it. Each registered application gets its own URL.

## Change it together

In the editor, choose **Refresh files**, select `hello-rawpair/index.html`, and change the heading. Choose **Save**, then refresh the preview. The page now reflects the saved file.

Open a second browser profile or private window, log in, and open the same workspace to try two participants on one machine. Edit the same file in both windows: changes appear in both editors. Both terminals attach to the same tmux session, so a command typed in one is visible in the other. While the demo server occupies that terminal window, press `Ctrl-b`, release both keys, then press `c` to open another tmux window.

Shared edits persist in the collaboration service, and **Save** writes them to the project filesystem. If Git or a terminal command changes a file already open in the shared editor, use **Reload from disk** to replace the shared copy. It asks for confirmation because this discards unsaved changes for everyone editing that file.

## Bring a friend or coworker

For a person joining from another computer, the installation must use remote mode with reachable management/preview DNS, HTTPS access and trusted certificates. Sending a `.localhost` URL points their browser at their own machine. Local mode binds nginx to loopback, so opening a firewall port alone does not make it remote.

1. The operator runs `sudo rawpair user add` on the host and securely gives the new person their own username/password.
2. On the workspace's management page, an owner enters that username under **Workspace members**, selects **Member**, and chooses **Add member**.
3. Send the workspace's management URL from your browser's address bar. They sign in and choose **Open editor and shared terminal**.
4. Make one change together, run a command, and open the private preview. Both of you use the same project files and running environment.

Members can edit, use the terminal, start/stop the workspace and open private previews. Owners also manage membership, limits, application routes and public sharing. Give owner access to people who should manage those choices.

To show **only the running application**, an owner can choose **Share publicly** for that application and confirm. Anyone who can reach the server and knows the preview URL can then open it without a RawPair login; editor and terminal access still requires workspace membership. Use **Make private** when you are done. Public sharing needs remote networking and trusted TLS; it does not change a local-only installation into a public server.

A small bug fix, onboarding exercise or weekend project makes a good first shared task. Send your teammate the [RawPair README](../README.md) if they would like to host their own instance.

## Try a second project on the same port

Create another workspace using `project-b`, start it, and repeat the demo there. Change its heading to identify the second project, and register its own `web` application on port `3000`.

You now have two development servers on the same port, each with a separate HTTPS preview. Stop the first workspace: its preview becomes unavailable, while the second keeps running. Start the first again and rerun the Python server; the files you saved are still there. A workspace start restores the shell and networking, but does not rerun development commands you launched earlier.

## Bring your own project

Use Git in a fresh workspace's terminal to clone your repository, install its dependencies and run its normal development command. The host operator installs shared language tools, or you install tools under the workspace's home. There is no sudo in a workspace and no automatic language installer. Git and your project's compiler/package manager may need to be installed first; the demo above needs none of those extras.

Bind an HTTP development server to `127.0.0.1` on a port from `1024` to `65535`, then register that port under **Applications**. Frameworks with Host checks may need the displayed preview hostname in their allowed-host list. Configure the external HTTPS/WebSocket URL for HMR when your framework requires it. You can register several named applications in one workspace.

## Come back later

- **Close the browser:** the workspace and its processes keep running.
- **Stop workspace:** all its processes stop; files remain. Start it again and rerun your development commands.
- **Restart the host:** workspaces start stopped. Use **Start / reconnect**, then restart your servers.
- **Remove workspace, preserve files:** registration is removed and the slot becomes available; the account's files remain for deliberate reuse.
- **Delete project contents:** a separate destructive operation requiring the exact runtime ID while the workspace is stopped.

Keep project files in Git and include workspace homes and collaboration state in your [backups](PACKAGES.md#packages-state-and-upgrades). If a step fails, use the [troubleshooting guide](PACKAGES.md#if-something-does-not-work). [Report what happened](https://github.com/rawpair/rawpair/issues) with your version and diagnostics, without credentials.

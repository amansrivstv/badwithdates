defmodule BadwithdatesWeb.UserLive.Confirmation do
  use BadwithdatesWeb, :live_view

  alias Badwithdates.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center px-4 py-8">
      <div class="w-full max-w-sm space-y-6">
        <div class="text-center">
          <.header>
            <p class="text-xl sm:text-2xl break-words">Welcome {@user.email}</p>
          </.header>
        </div>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
          class="space-y-4"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <div class="space-y-3">
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirming..."
              class="btn btn-primary w-full h-12 text-base touch-manipulation"
            >
              <span class="text-center">Confirm and stay logged in</span>
            </.button>
            <.button
              phx-disable-with="Confirming..."
              class="btn btn-primary btn-soft w-full h-12 text-base touch-manipulation"
            >
              <span class="text-center">Confirm and log in only this time</span>
            </.button>
          </div>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
          class="space-y-4"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <%= if @current_scope do %>
            <.button
              phx-disable-with="Logging in..."
              class="btn btn-primary w-full h-12 text-base touch-manipulation"
            >
              <span class="text-center">Log in</span>
            </.button>
          <% else %>
            <div class="space-y-3">
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                class="btn btn-primary w-full h-12 text-base touch-manipulation"
              >
                <span class="text-center leading-tight">Keep me logged in on this device</span>
              </.button>
              <.button
                phx-disable-with="Logging in..."
                class="btn btn-primary btn-soft w-full h-12 text-base touch-manipulation"
              >
                <span class="text-center">Log me in only this time</span>
              </.button>
            </div>
          <% end %>
        </.form>

        <div :if={!@user.confirmed_at} class="alert alert-outline text-sm">
          <p class="break-words leading-relaxed">
            <strong class="font-medium">Tip:</strong>
            If you prefer passwords, you can enable them in the user settings.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end

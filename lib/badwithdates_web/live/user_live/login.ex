defmodule BadwithdatesWeb.UserLive.Login do
  use BadwithdatesWeb, :live_view

  alias Badwithdates.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center px-4 py-8">
      <div class="w-full max-w-sm space-y-6">
        <div class="text-center">
          <.header>
            <p class="text-2xl sm:text-3xl">Log in</p>
            <:subtitle>
              <div class="text-sm sm:text-base leading-relaxed">
                <%= if @current_scope do %>
                  You need to reauthenticate to perform sensitive actions on your account.
                <% else %>
                  Don't have an account? <.link
                    navigate={~p"/users/register"}
                    class="font-semibold text-brand hover:underline break-words"
                    phx-no-format
                  >Sign up</.link> for an account now.
                <% end %>
              </div>
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info text-sm">
          <.icon name="hero-information-circle" class="size-5 sm:size-6 shrink-0 mt-0.5" />
          <div class="min-w-0">
            <p class="break-words">You are running the local mail adapter.</p>
            <p class="break-words">
              To see sent emails, visit <.link href="/dev/mailbox" class="underline break-words">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
          class="space-y-4"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
            class="text-base"
          />
          <.button class="btn btn-primary w-full h-12 text-base touch-manipulation">
            <span class="flex items-center justify-center gap-2">
              Log in with email <span aria-hidden="true" class="text-lg">→</span>
            </span>
          </.button>
        </.form>

        <div class="divider text-sm">or</div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
          class="space-y-4"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            class="text-base"
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            class="text-base"
          />
          <div class="space-y-3">
            <.button
              class="btn btn-primary w-full h-12 text-base touch-manipulation"
              name={@form[:remember_me].name}
              value="true"
            >
              <span class="flex items-center justify-center gap-2">
                Log in and stay logged in <span aria-hidden="true" class="text-lg">→</span>
              </span>
            </.button>
            <.button class="btn btn-primary btn-soft w-full h-12 text-base touch-manipulation">
              Log in only this time
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:badwithdates, Badwithdates.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end

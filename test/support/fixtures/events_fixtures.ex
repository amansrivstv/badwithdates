defmodule Badwithdates.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Badwithdates.Events` context.
  """

  @doc """
  Generate a event.
  """
  def event_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        category: :anniversary,
        date: ~D[2025-07-23],
        description: "some description",
        title: "some title"
      })

    {:ok, event} = Badwithdates.Events.create_event(scope, attrs)
    event
  end
end

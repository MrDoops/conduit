defmodule Conduit.Plug.CreatedBy do
  use Conduit.Plug.Builder
  @moduledoc """
  Assigns name of app to created_by of the message.

      plug Conduit.Plug.CreatedBy, app: "myapp"

  """

  def init(opts) do
    Keyword.fetch!(opts, :app)
    |> to_string
  end

  @doc """
  Assigns created_by.

  ## Examples

      iex> message = Conduit.Plug.CreatedBy.run(%Conduit.Message{}, "myapp")
      iex> message.created_by
      "myapp"
  """
  def call(message, next, created_by) do
    message
    |> put_created_by(created_by)
    |> next.()
  end
end

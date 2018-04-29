defmodule Conduit.Plug.Builder do
  @moduledoc """
  A module that can be used to build plugs.

  You can also use plugs within your custom plug. The plugs
  will be run before `call/3`.

  ## Examples

      iex> import Conduit.Message
      iex>
      iex> defmodule MyPipeline do
      iex>   use Conduit.Plug.Builder
      iex>
      iex>   plug Conduit.Plug.Format
      iex>   plug Conduit.Plug.Encode
      iex> end
      iex>
      iex> message =
      iex>   %Conduit.Message{}
      iex>   |> put_body("hi")
      iex>   |> MyPipeline.run
      iex> message.body
      "hi"
      iex> message.content_type
      "text/plain"
      iex> message.content_encoding
      "identity"
  """
  @type plug :: module | atom

  alias Conduit.Util

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Conduit.Plug
      import Conduit.Message
      import Conduit.Plug.MessageActions
      import Conduit.Plug.Builder, only: [plug: 1, plug: 2]
      alias Conduit.Message

      def init(opts) do
        opts
      end

      def call(message, next, _opts) do
        next.(message)
      end

      defoverridable init: 1, call: 3

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Conduit.Plug.Builder
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    plugs = [{:call, quote(do: opts)} | Module.get_attribute(env.module, :plugs)]
    pipeline = compile(plugs, quote(do: next))

    quote do
      def run(message, opts \\ []) do
        opts = init(opts)

        __build__(& &1, opts).(message)
      end

      def __build__(next, opts) do
        unquote(pipeline)
      end
    end
  end

  @doc """
  A macro that stores a new plug. `opts` will be passed unchanged to the new
  plug.

  ## Examples

      plug Conduit.Plug.Format                  # plug module
      plug :put_content_encoding, "gzip"        # plug function

  """
  defmacro plug(plug, opts \\ [])

  defmacro plug(plug, {label, _, _} = fun) when label in [:&, :fn] do
    quote bind_quoted: [plug: plug, fun: Macro.escape(fun)] do
      @plugs {plug, fun}
    end
  end

  defmacro plug(plug, opts) do
    quote bind_quoted: [plug: plug, opts: opts] do
      @plugs {plug, opts}
    end
  end

  def compile(plugs, last) do
    Enum.reduce(plugs, last, &quote_plug/2)
  end

  defp quote_plug({plug, opts}, next) do
    case Atom.to_charlist(plug) do
      ~c"Elixir." ++ _ -> quote_module_plug(plug, next, opts)
      _ -> quote_fun_plug(plug, next, opts)
    end
  end

  defp quote_module_plug(plug, next, opts) do
    if Code.ensure_compiled?(plug) do
      opts =
        opts
        |> plug.init
        |> escape_opts

      quote do
        unquote(plug).__build__(unquote(next), unquote(opts))
      end
    else
      raise Conduit.UnknownPlugError, "Couldn't find module #{inspect(plug)}"
    end
  end

  defp quote_fun_plug(plug, next, opts) do
    quote do
      fn message ->
        unquote(plug)(message, unquote(next), unquote(escape_opts(opts)))
      end
    end
  end

  defp escape_opts({:opts, [], Conduit.Plug.Builder} = opts), do: opts
  defp escape_opts(opts), do: Util.escape(opts)
end

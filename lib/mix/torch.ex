defmodule Mix.Torch do
  @moduledoc false

  alias Torch.Config

  def parse_config!(task, args) do
    {opts, _, _} = OptionParser.parse(args, switches: [format: :string, app: :string])

    format = convert_format(opts[:format] || Config.template_format())
    otp_app = opts[:app] || Config.otp_app()

    unless otp_app do
      Mix.raise("""
      You need to specify an OTP app to generate files within. Either
      configure it as shown below or pass it in via the `--app` option.

          config :torch,
            otp_app: :my_app

          # Alternatively
          mix #{task} --app my_app
      """)
    end

    unless format in ["eex", "slime"] do
      Mix.raise("""
      Template format is invalid: #{inspect(format)}. Either configure it as
      shown below or pass it via the `--format` option.

          config :torch,
            template_format: :slime

          # Alternatively
          mix #{task} --format slime

      Supported formats: eex, slime
      """)
    end

    %{otp_app: otp_app, format: format}
  end

  def ensure_phoenix_is_loaded(mix_task) do
    case Application.load(:phoenix) do
      :ok ->
        :ok

      {:error, {:already_loaded, :phoenix}} ->
        :ok

      {:error, reason} ->
        Mix.raise(
          "mix #{mix_task} could not complete due to Phoenix not being loaded: #{reason}"
        )
    end
  end

  defp convert_format("slim"), do: "slime"
  defp convert_format(format), do: format
end

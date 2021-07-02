defmodule Torch.Pagination do
  @moduledoc """
  Handles torch pagination configuration.

  ## Usage

  To have pagination for your Torch page `lib/my_project/accounts.ex`
  the following way:

      defmodule MyApp.Accounts do
        use Torch.Pagination,
          repo: MyApp.Repo,
          model: MyApp.Accounts.User,
          name: :users,
          page_size: 15,
          pagination_distance: 5,
      end

  Options `page_size` and `pagination_distance` are optional per pagination.

  Defaults are:
    `page_size`: 15
    `pagination_distance`: 5

  You can configure `page_size` and `pagination_distance` on app level in the config.exs:

    config :torch,
      otp_app: :my_app,
      page_size: 20,
      pagination_distance: 5

  The following Torch context methods will be created:

    * public `paginate_users/1`
    * private `do_paginate_users/2`
    * private `filter_config/1`

  ## Configuration options

    * `:repo` - the ecto repo module (required)
    * `:model` - the user schema module (required)
    * `:name` - name of the collection that needs pagination (required)
  """
  defmacro __using__(opts) do
    name = Keyword.get(opts, :name)
    repo = Keyword.get(opts, :repo)
    model = Keyword.get(opts, :model)
    page_size = Keyword.get(opts, :page_size) || Application.get_env(:torch, :page_size, 15)

    pagination_distance =
      Keyword.get(opts, :pagination_distance) ||
        Application.get_env(:torch, :pagination_distance, 5)

    quote do
      import Torch.Helpers, only: [sort: 1, paginate: 4]
      import Filtrex.Type.Config

      @spec unquote(:"paginate_#{name}")(map) :: {:ok, map} | {:error, any}
      def unquote(:"paginate_#{name}")(params \\ %{}) do
        params =
          params
          |> Map.put_new("sort_direction", "desc")
          |> Map.put_new("sort_field", "inserted_at")

        {:ok, sort_direction} = Map.fetch(params, "sort_direction")
        {:ok, sort_field} = Map.fetch(params, "sort_field")

        with {:ok, filter} <-
               Filtrex.parse_params(filter_config(unquote(:"#{name}")), params["activity"] || %{}),
             %Scrivener.Page{} = page <- unquote(:"do_paginate_#{name}")(filter, params) do
          {
            :ok,
            %{
              unquote(name) => page.entries,
              page_number: page.page_number,
              page_size: page.page_size,
              total_pages: page.total_pages,
              total_entries: page.total_entries,
              distance: unquote(pagination_distance),
              sort_field: sort_field,
              sort_direction: sort_direction
            }
          }
        else
          {:error, error} -> {:error, error}
          error -> {:error, error}
        end
      end

      @spec unquote(:"do_paginate_#{name}")(Filtrex.t(), Keyword.t()) :: Scrivener.Page.t()
      defp unquote(:"do_paginate_#{name}")(filter, params) do
        pagination = [page_size: unquote(page_size)]

        unquote(model)
        |> Filtrex.query(filter)
        |> order_by(^sort(params))
        |> paginate(unquote(repo), params, pagination)
      end

      @spec filter_config(String.t()) :: list(Filtrex.Type.Config.t())
      defp filter_config(unquote(:"#{name}")) do
        defconfig do
          fields = unquote(model).__schema__(:query_fields)

          Enum.each(fields, fn field ->
            type = unquote(model).__schema__(:type, field)

            cond do
              type in [:integer, :number] -> number(field)
              type in [:naive_datetime, :utc_datetime, :datetime, :date] -> date(field)
              type in [:boolean] -> boolean(field)
              true -> text(field)
            end
          end)
        end
      end
    end
  end
end

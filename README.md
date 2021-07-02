[![License](https://img.shields.io/hexpm/l/torch.svg)](https://github.com/mojotech/torch/blob/master/LICENSE)
[![Hex.pm](https://img.shields.io/hexpm/v/torch.svg)](https://hex.pm/packages/torch)
[![Build Status](https://github.com/mojotech/torch/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/mojotech/torch/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/mojotech/torch/badge.svg?branch=master)](https://coveralls.io/github/mojotech/torch?branch=master)

# Torch

Torch is a rapid admin generator for Phoenix applications. It creates custom templates and relies
on the Phoenix HTML generator under the hood.

![image](https://user-images.githubusercontent.com/7085617/36333572-70e3907e-132c-11e8-9ad2-bd5e98aadc7c.png)

## Installation

To install Torch, perform the following steps:

1. Add `torch` to your list of dependencies in `mix.exs`. Then, run `mix deps.get`:

```elixir
def deps do
  [
    {:torch, "~> 3.6"}
  ]
end
```

2. Add a `Plug.Static` plug to your `endpoint.ex`:

```elixir
plug(
  Plug.Static,
  at: "/torch",
  from: {:torch, "priv/static"},
  gzip: true,
  cache_control_for_etags: "public, max-age=86400"
)
```

3. Configure Torch by adding the following to your `config.exs`.

```
config :torch,
  otp_app: :my_app_name,
  template_format: "eex" || "slime"
```

4. Run `mix torch.install`

**NOTE:** You can also choose to use `slime` templates, but you will need to
first [install Phoenix Slime](https://github.com/slime-lang/phoenix_slime) and
then update your configuration to specify `template_format: "slime"`.

Now you're ready to start generating your admin! :tada:

## Usage

Torch uses Phoenix generators under the hood. Torch injects it's own custom templates
into your `priv/static` directory, then runs the `mix phx.gen.html` task with the options
you passed in. Finally, it uninstalls the custom templates so they don't interfere with
running the plain Phoenix generators.

In light of that fact, the `torch.gen.html` task takes all the same arguments as the `phx.gen.html`,
but does some extra configuration on either end. Checkout `mix help phx.gen.html` for more details
about the supported options and format.

For example, if we wanted to generate a blog with a `Post` model we could run the following command:

```bash
$ mix torch.gen.html Blog Post posts title:string body:text published_at:datetime published:boolean views:integer
```

The output would look like:

```bash
Add the resource to your browser scope in lib/my_app_web/router.ex:

    resources "/posts", PostController

Ensure the following is added to your endpoint.ex:

    plug(
      Plug.Static,
      at: "/torch",
      from: {:torch, "priv/static"},
      gzip: true,
      cache_control_for_etags: "public, max-age=86400",
      headers: [{"access-control-allow-origin", "*"}]
    )

  :fire: Torch generated html for Posts! :fire:
```

Torch also installed an admin layout into your `my_app_web/templates/layout/torch.html.eex`.
You will want to update it to include your new navigation link:

```
<nav class="torch-nav">
  <a href="/posts">Posts</a>
</nav>
```

There may be times when you are adding Torch into an already existing system
where your application already contains the modules and controllers and you just
want to use the Torch admin interface. Since the `torch.gen` mix tasks are just
wrappers around the existing `phx.gen` tasks, you can use most of the same
flags. To add an admin interface for `Posts` in the previous example, where the
model and controller modules already exist, use the following command:

```bash
$ mix torch.gen.html Blog Post posts --no-schema --no-context --web Admin title:string body:text published_at:datetime published:boolean views:integer
```

### Association filters

Torch does not support association filters at this time. [Filtrex](https://github.com/rcdilorenzo/filtrex) does not yet support them.

You can checkout these two issues to see the latest updates:

https://github.com/rcdilorenzo/filtrex/issues/55

https://github.com/rcdilorenzo/filtrex/issues/38

However, that does not mean you can't roll your own.

**Example**

We have a `Accounts.User` model that `has_many :credentials, Accounts.Credential` and we want to support filtering users
by `credentials.email`.

1. Add Torch pagination to the `Accounts` domain:

```elixir
# accounts.ex

  use Torch.Pagination,
    repo: MyApp.Repo,
    model: MyApp.Accounts.User,
    name: :users

```

**NOTE** If you want to customize the pagination functions at all for your application, do not use the default `Torch.Pagination` as described above; instead you will need to define your own `paginate_*/2` method that will return a `Scrivener.Page` object.  You can also define your own pagination system and functions as well, but that will require further customization of the generated Torch controllers as well.

```elixir
# accounts.ex
...
defp do_paginate_users(filter, params) do
  credential_params = Map.get(params, "credentials")
  params = Map.drop(params, ["credentials"])

  User
  |> Filtrex.query(filter)
  |> credential_filters(credential_params)
  |> order_by(^sort(params))
  |> paginate(Repo, params, @pagination)
end

defp credential_filters(query, nil), do: query

defp credential_filters(query, params) do
  search_string = "%#{params["email"]}%"

  from(u in query,
    join: c in assoc(u, :credentials),
    where: like(c.email, ^search_string),
    group_by: u.id
  )
end
...
```

2. Update form filters.

```eex
# users/index.html.eex
<div class="field">
  <label>Credential email</label>
  <%= text_input(:credentials, :email, value: maybe(@conn.params, ["credentials", "email"])) %>
</div>
```

Note: You'll need to install & import `Maybe` into your views `{:maybe, "~> 1.0.0"}` for
the above `eex` to work.

## Styling

Torch generates two CSS themes you can use: `base.css` & `theme.css`.
The base styles are basically bare bones, and the theme styles look like the screenshot
above. Just change the stylesheet link in the `torch.html.eex` layout.

If you want to use the theme, but override the colors, you'll need to include your
own stylesheet with the specific overrides.

## Internationalization

Torch comes with `.po` files for several locales. If you are using
Torch and can provide us with translation files for other languages, please
submit a Pull Request with the translation file. We'd love to add as many
translations as possible.

If you wish to add your own customized translations, you can configure Torch to
use your own custom `MessagesBackend` and adding it in your Torch configuration
settings in `config.exs`. You can find the all messages that can be customized
in the default [i18n/backend.ex](lib/torch/i18n/backend.ex) file.

If you are customizing a backend for a "standard" spoken language, please submit
back a proper `.po` translation file for us to include in the official Torch
releases so other users can take advantage.

**Example**

```elixir
defmodule MyApp.CustomMessagesBackend do
  def message("Contains"), do: "** CUSTOM Contains **"
  def message("Equals"), do: "** CUSTOM Equals ****"
  def message("< Prev"), do: "<--"
  def message("Next >"), do: "-->"

  # You can add a fallback so it won't break with newly added messages or
  # messages you did not customize
  def message(text), do: Torch.I18n.Backend.message(text)
end
```

```elixir
# config.exs
config :torch,
  otp_app: :my_app_name,
  i18n_backend: MyApp.CustomMessagesBackend
  template_format: "eex" || "slime"
```

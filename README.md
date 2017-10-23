# Guaxinim

![Guaxinim = Racoon](assets/logo/logo.png)


Quick n' dirty literate programming for Elixir, inspired by
[Docco](http://ashkenas.com/docco/)
and [Pyccoon](http://ckald.github.io/pyccoon/)

Unlike both Docco and Pyccoon (and any of the other Docco clones),
Guaxinim turns your Elixir sources into hyperlinked HTML webpages,
with links from each function or macro call into it's definition.
You can browse Guaxinim's source rendered by Guaxinim itself here:
[https://tmbb.github.io/guaxinim/guaxinim.ex.html](https://tmbb.github.io/guaxinim/guaxinim.ex.html)

Regarding hyperlinks, Guaxinim supports the following:

  * If the function/macro was defined into your own project, the link leads to the local function definition in the same project (in the same page or in a different page)
  * If the function/macro is defined in an external dependency from Hex or from the Elixir standard library, the link leads to the corresponding function head at [hexdocs.pm](https://hexdocs.pm).
  * If the function is defined in the Erlang standard library, the link leads to the Erlang docs

For examples of all these kinds of links, see this dummy module from Guaxinim's own source:
[https://tmbb.github.io/guaxinim/guaxinim_test.ex.html](https://tmbb.github.io/guaxinim/guaxinim_test.ex.html)

Text in comments or documentation attributes (`@doc`, `@moduledoc`, `@typedoc`)
is treated as Markdown and rendered into HTML.
Currently, documentation attributes must be heredocs (`doc """\n...\n"""`).
Other sigils are not supported yet, even if they return strings.
The process of extracting the text from the source is lexical only.
The Elixir code is not executed or interpreted.

## Installation

The package is [available in Hex](https://hex.pm/docs/publish).
It can be installed by adding `guaxinim` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:guaxinim, "~> 0.1.0"}
  ]
end
```

## User Manual

To use, just run the mix task in the command line:

```
mix guaxinim.render
```

This will create a directory named `literate/` which will contain an entire website
with the rendered sources from your project.

## Previewing the Literate Source

Unlike ExDoc, for example, Guaxinim generates a hierarchy of nested files and directories,
mirroring your project's actual layout on the file system.
Most browsers won't show the styles correctly if you open the files directly.
To preview them properly, you should start an HTTP server inside the `literate/` directory.

A good option is the default HTTP server bundled with Python's standard library.
To use it, run the following command inside the `literate/` directory (if you're using Python 3):

```
python -m http.server 8000
```

Or the following (if you're using Python 2):

```
python -m SimpleHTTPServer 8000
```

Then, point your browser at: [http://localhost:8000/](http://localhost:8000/)
and explore the sources

TODO: Document configuration options

## Differences from Other "Inverse Literate Programming" Tools

Like other "inverse literate programming" tools, Guaxinim highlights the source code
of the files and allows rich texts in the form of Markdown (which is rendered into HTML).

On the other hand, Guaxinim is relatively innovative in that it can link functions
in the source to their definitions.
This makes it very easy to explore the source of an new project, as you can always
go to the place where a function is defined.
This can ony be done because Guaxinim deeply integrates with your mix project,
and leverages tools like the BEAM debug chunks and the Mix.Xref module.
Unlike other tools like Pyccoon, which supports multiple programming languages,
Guaxinim is specialized for Elixir code.
While it might highlight other programming languages in the future,
providing hyperlinks in other programming languages is unlikely.

Another distinctive feature of Guaxinim is the fact that it uses the Makeup syntax highlighting tool.
Makeup is a pure Elixir Syntax highlighting library, which is particularly good at highlighting Elixir
(better than [highlights.js](https://highlightjs.org/), used by many such tools and
[Pygments](http://pygments.org/), used by Python-based tools).

## The Name

Guaxinim is the Portuguese word for raccoon.
It was taken from the Old Tupi, spoken by the Tupi Indians in Brazil,
and later adopted by the Portuguese occupiers and their foreign slaves.
I also has an X in the name, which connects it to Elixir.

The logo is the stylized picture of a raccoon.
The name was inspired by the Pyccoon inverse literate-programming tool
(which by some reason has raccoon as it's logo).

By naming this after a Portuguese word, I'm contributing to the success of the Brazilian
programming-language conspiracy, as discussed here:
[https://elixirforum.com/t/discussion-about-syntax-preferences-split-posts/3436/81](https://elixirforum.com/t/discussion-about-syntax-preferences-split-posts/3436/81)
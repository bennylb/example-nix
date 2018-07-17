- [Introduction](#orgab3a165)
- [Prerequisites](#org12d9491)
- [Following along with code](#orgcecac21)
- [Walk-through](#org383c53a)
  - [Basic build](#org517eaae)
  - [Modifying the Haskell build](#orga80e003)
- [Developing Haskell](#org3c12cee)
  - [Development tools in a Nix shell](#org1e125fe)
  - [Cabal](#org37a01c2)
  - [Accidentally building outside a Nix shell](#org66f1e64)
  - [Ghcid](#orgfb91a0e)
  - [Editor tags files](#org031ddef)
  - [Dante](#orgb683f55)
  - [Haskell Stack](#orgc1b9c4f)
  - [Stack-less change-triggered builds](#org9b37987)



<a id="orgab3a165"></a>

# Introduction

This is a tutorial using this project's [Pkgs-make](../../pkgs-make) to manage a Haskell project.

Although Haskell as a programming language has some extremely modern features, it's a mature language with over 20 years of history. That kind of legacy has led to some tooling complexity.

For a while, the ergonomics of working with Haskell were incredibly lacking, but in 2015, [Haskell Stack](http://haskellstack.org) was released and introduced a single tool that ostensibly could perform most workflows people had. Download and install one tool, and it does the rest. Prior to Stack, Haskell programmers would have to manage installations of the [Glasgow Haskell Compiler (GHC)](https://www.haskell.org/ghc/) as well as the [Cabal build tool](https://haskell.org/cabal). And it can be [confusing to manage multiple versions](https://www.snoyman.com/blog/2018/07/stop-supporting-older-ghcs) for different projects.

Beyond the versions of GHC and Cabal, we also have to manage all our libraries. Recently, [Cabal has had improvements](http://blog.ezyang.com/2016/05/announcing-cabal-new-build-nix-style-local-builds/) that makes [Cabal's feature set closer to Stack's](http://blog.ezyang.com/2016/08/cabal-new-build-is-a-package-manager/), and both tools now similarly manage the installation of third-party Haskell libraries required by a Haskell project. However, neither tool manages the installation of non-Haskell libraries (often for C FFI). They delegate this responsibility to an OS package manager, which is exactly what Nix is.

But Nix is not a typical package manager. By its nature, we can use Nix as our build system too (though it delegates to typical build tools in the background).

Ideally, we want a way to

1.  manage all of our third-party dependencies &#x2013; both Haskell and non-Haskell
2.  accomodate a healthy diversity of developer workflows
3.  have comfortable ergonomics.

This tutorial shows how to obtain the first of our goals with Nix. The second two are always a work in process, but we feel we have something workable.


<a id="org12d9491"></a>

# Prerequisites

We'll presume you're familiar with Haskell and the tooling ecosystem.

We'll assume that you know what's covered in the previous two tutorials [introducing Nix](../0-nix-intro/README.md) and [introducing Pkgs-make](../1-pkgs-make/README.md).


<a id="orgcecac21"></a>

# Following along with code

Similar to the previous tutorial, our example Haskell project is split into two packages:

-   **[`example-haskell-lib`](./library):** a library with a few modules offering very simple functions

-   **[`example-haskell-app`](./application):** an executable that prints a message to the console, depending on `example-haskell-lib` as well as a third-party library called Protolude.

Here's an example run of it:

```shell
nix run -f build.nix example-haskell-app -c example-haskell
```

    Answer to the Ultimate Question of Life,
        the Universe, and Everything: 42

This is a trivial application. The complexity we're introducing is just enough to showcase usage of Nix.


<a id="org383c53a"></a>

# Walk-through


<a id="org517eaae"></a>

## Basic build

The library and application code should be familiar to most Haskell developers.

Notice how there's no Nix files in these projects at all. All we have is our source code, and a normal Cabal file. Pkgs-make uses a tool called `cabal2nix` to generate a Nix expression from a Cabal file on our behalf. We'll discuss this more later.

Notice how similar the [`build.nix` usage for this tutorial](./build.nix) is to the previous tutorial introducing Pkgs-make. The first difference to note is that because we're building a Haskell application we're using the `call.haskell.lib` and `call.haskell.app` attributes rather than `call.package`:

```text
pkgsMake pkgsMakeArgs ({ call, lib, ... }: rec {
    example-haskell-lib = call.haskell.lib ./library;
    example-haskell-app = call.haskell.app ./application;
    …
}
```

The `call.package` attribute uses NixPkgs's top-level callPackage function, which is tailored to build shell and C/C++ applications. For other languages, we need other callPackage functions from Nixpkgs. Pkgs-make helps set these up and makes them available on the `call` set.

Also, similarly to the previous tutorial, there are three attributes to illustrate putting the project in Docker and generating a license report:

-   **`example-haskell-docker`:** a loadable Docker image built purely with Nix

-   **`example-haskell-tarball`:** a tarball that can be used with [this tutorial's `Dockerfile`](./Dockerfile) to create an image using Docker

-   **`example-haskell-licenses`:** a license report.

Since they work the same way as shown in the previous tutorial, we don't discuss them more there, but the [top-level `run` directory](../../run/README.md) has scripts that illustrate their use.


<a id="orga80e003"></a>

## Modifying the Haskell build

Nixpkgs has tried to have reasonable defaults for building a Haskell library or application, but occasionally we might want to modify the build. For instance, we may want to alter whether we compile for profiling, generate Haddock documentation, or ignore version bounds in Cabal files.

Nixpkgs offers [some functions useful for modifying the build of a Haskell application](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/haskell-modules/lib.nix). These functions are passed to an invocation of Pkgs-make on the `lib.haskell` attribute.

In this tutorial we'll focus on `lib.haskell.dontHaddock` as an example. Haskell libraries built by Nixpkgs by default also generate Haddock documentation. But sometimes, this breaks or takes a long time. We can use `dontHaddock` to suppress this part of the build.

Some derivations have multiple outputs, and whose derivations can be accessed by attributes on the derivation. For instance, to get to the generated Haddocks for our `example-haskell-lib` library, we can reference the `example-haskell-lib.doc` attribute:

```shell
tree "$(nix path-info --file build.nix example-haskell-lib.doc)"
```

    /nix/store/z7rva5ybv3hydvcq2xjmxaanzrmpjc44-example-haskell-lib-0.1.0.0-doc
    └── share
        └── doc
            └── example-haskell-lib-0.1.0.0
                └── html
                    ├── doc-index.html
                    ├── example-haskell-lib.haddock
                    ├── example-haskell-lib.txt
                    ├── haddock-util.js
                    ├── hslogo-16.png
                    ├── index.html
                    ├── Lib.html
                    ├── minus.gif
                    ├── ocean.css
                    ├── plus.gif
                    ├── src
                    │   ├── FortyOne.html
                    │   ├── hscolour.css
                    │   └── Lib.html
                    └── synopsis.png
    
    5 directories, 14 files

This tutorial's [`build.nix`](./build.nix) file shows three ways to modify the `example-haskell-lib` build. The first way is to use `lib.haskell.dontHaddock` directly:

```text
example-haskell-lib-nodoc-1 =
    lib.haskell.dontHaddock example-haskell-lib;
```

`example-haskell-lib-nodoc-1` is assigned a version of `example-haskell-lib` modified to have no documentation. We can see this when we try to build the documentation because the `doc` subattribute will be missing:

```shell
nix path-info --file build.nix \
    example-haskell-lib-nodoc-1.doc 2>&1 || true
```

    error: attribute 'doc' in selection path 'example-haskell-lib-nodoc-1.doc' not found

To illustrate two other methods of modifying packages, `build.nix` has two attributes that seem at first glance like unmodified versions:

```text
example-haskell-lib-nodoc-2 = example-haskell-lib;

example-haskell-lib-nodoc-3 = example-haskell-lib;
```

But these attributes will indeed be modified by Pkgs-make because of arguments passed to it:

```text
pkgsMakeArgs.haskellArgs = {
    pkgChanges = lib: {
	example-haskell-lib-nodoc-2 = [ lib.haskell.dontHaddock ];
    };
    changePkgs = {
	dontHaddock = [ "example-haskell-lib-doc-3" ];
    };
};
```

The `haskellArgs.pkgChanges` attribute can be set to a function that returns a set mapping package attribute names to lists of modifications from `lib.haskell` (`lib` is passed to the function). This may seem more verbose and confusing than the first method shown, but this method allows us not only to modify our library, but also third-party Haskell libraries already in Nixpkgs.

Conversely, the `changePkgs` attribute can be set to an attribute set mapping the attribute names of functions on `lib.haskell` to a list of attributes names of Haskell packages. Similarly to `pkgChanges`, these packages can either be new ones we're building with Pkgs-make or third-party ones coming from Nixpkgs.

One benefit of `changePkgs` over the other methods is a convenient way to temporarily modify packages with `enableLibraryProfiling` in one place for various libraries of interest without disturbing the rest of the file.

Unfortunately, the design of `changePkgs` only works for functions in `lib.haskell` that don't require the application of more arguments than the package to be modified.

With three methods to modify packages with Pkgs-make, hopefully you can find one that works well for your needs.


<a id="org3c12cee"></a>

# Developing Haskell

We introduced `nix-shell` at the end of the [first tutorial](../0-nix-intro/README.md). We'll now see how we can use Pkgs-make with `nix-shell` to get a rich programming environment for a Haskell project built with Nix.


<a id="org1e125fe"></a>

## Development tools in a Nix shell

Pkgs-make generates for us special derivations tailored for use with `nix-shell` to develop multi-module projects. These derivations are returned by Pkgs-make in addition to the derivations we explicitly specify. The one tailored for Haskell are on the `env.haskell` attribute.

We have in this tutorial a [`shell.nix` file](./shell.nix) that accesses this attribute from the tutorial's `build.nix`.

```nix
(import ./build.nix).env.haskell.withEnvTools (pkgs: [ pkgs.hello ])
```

By default, Pkgs-make's Haskell environment has the following tools:

-   `ghc`
-   `cabal`
-   `ghcid`
-   `nix-tags-haskell`
-   `cabal-new-watch`

As illustrated in our `shell.nix` we can also include other tools. We show including GNU Hello (not that it's relevant/useful for Haskell development).

You can call `nix-shell` with no arguments to enter into an interactive shell, or we can run commands in it non-interactively. For instance, here we show that the discussed tools are on our `PATH` provided by Nix:

```shell
nix-shell --run '
    which ghc
    which ghci
    which ghcid
    which cabal
    which nix-tags-haskell
    which cabal-new-watch
    which hello
'
```

    /nix/store/q2prxgva7999iwz4rfcyhkjsmjxv3l65-ghc-8.2.2-with-packages/bin/ghc
    /nix/store/q2prxgva7999iwz4rfcyhkjsmjxv3l65-ghc-8.2.2-with-packages/bin/ghci
    /nix/store/w4vdrfr2b9gs7iyaax17jgjrpmv3wgmr-ghcid-0.6.10/bin/ghcid
    /nix/store/m46vcdhpsb027ik71vs0bjh5hf85n1j4-cabal-install-2.2.0.0/bin/cabal
    /nix/store/dk44xyy25xfgl4xjbfrwamwvn3axgp1z-nix-tags-haskell/bin/nix-tags-haskell
    /nix/store/vdkwrvjfpfipq0hs7cjkwklpzfsl6wzc-cabal-new-watch/bin/cabal-new-watch
    /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello

The instance of GHC provided is a “-with-packages” version preloaded with all the external libraries and tools declared as dependencies gleaned from our project's two Cabal files (`example-haskell-lib.cabal` and `example-haskell-app.cabal`). This way versions of external dependencies are explicitly pinned to the versions coming from Nixpkgs, and not resolved dynamically by Cabal.

One consequence of this is that once you enter into a Nix shell for a derivation, you can disable your computer's networking. Entering the shell should download all the dependencies you need from the internet, and check their hashes to assure a deterministic build. From there, you should only need your source code, which should should be able to compile and work with offline.


<a id="org37a01c2"></a>

## Cabal

When we built our project before with `nix build` it used Cabal internally, but we can use `nix-shell` to call `cabal` explicitly.

The provided version of Cabal is recent enough that we can use its latest [“new-\*” support for multiple-package projects](http://blog.ezyang.com/2016/05/announcing-cabal-new-build-nix-style-local-builds/). Our tutorial's [`cabal.project` file](./cabal.project) tells Cabal that our project includes both our library and application package:

```text
packages:
    library
    application
```

Note that this `cabal.project` file is not used by a normal Nix build. We're just using it for development with `nix-shell`.

We'll show building our project with the `--run` switch of `nix-shell`:

```shell
nix-shell --run '
    cabal new-update
    cabal new-configure
    cabal new-build all'
```

    Downloading the latest package list from hackage.haskell.org
    To revert to previous state run:
        cabal new-update 'hackage.haskell.org,2018-08-30T03:06:31Z'
    Resolving dependencies...
    Build profile: -w ghc-8.2.2 -O1
    In order, the following would be built (use -v for more details):
     - example-haskell-lib-0.1.0.0 (lib) (first run)
     - example-haskell-app-0.1.0.0 (exe:example-haskell) (first run)
    Build profile: -w ghc-8.2.2 -O1
    In order, the following will be built (use -v for more details):
     - example-haskell-lib-0.1.0.0 (lib) (first run)
     - example-haskell-app-0.1.0.0 (exe:example-haskell) (first run)
    Configuring library for example-haskell-lib-0.1.0.0..
    Preprocessing library for example-haskell-lib-0.1.0.0..
    Building library for example-haskell-lib-0.1.0.0..
    [1 of 2] Compiling FortyOne         ( src/FortyOne.lhs, /home/shajra/src/shajra/example-nix/tutorials/2-haskell/dist-newstyle/build/x86_64-linux/ghc-8.2.2/example-haskell-lib-0.1.0.0/build/FortyOne.o )
    [2 of 2] Compiling Lib              ( src/Lib.hs, /home/shajra/src/shajra/example-nix/tutorials/2-haskell/dist-newstyle/build/x86_64-linux/ghc-8.2.2/example-haskell-lib-0.1.0.0/build/Lib.o )
    Configuring executable 'example-haskell' for example-haskell-app-0.1.0.0..
    Preprocessing executable 'example-haskell' for example-haskell-app-0.1.0.0..
    Building executable 'example-haskell' for example-haskell-app-0.1.0.0..
    [1 of 1] Compiling Main             ( src/Main.hs, /home/shajra/src/shajra/example-nix/tutorials/2-haskell/dist-newstyle/build/x86_64-linux/ghc-8.2.2/example-haskell-app-0.1.0.0/x/example-haskell/build/example-haskell/example-haskell-tmp/Main.o )
    Linking /home/shajra/src/shajra/example-nix/tutorials/2-haskell/dist-newstyle/build/x86_64-linux/ghc-8.2.2/example-haskell-app-0.1.0.0/x/example-haskell/build/example-haskell/example-haskell ...

The last line shows where your Cabal-built binary can be found under `dist-new-style`. This is where most of Cabal's artifacts are placed. Deleting this directory cleans the build.

It's linked and ready to run:

```shell
find dist-newstyle -name example-haskell -type f -exec {} +
```

    Answer to the Ultimate Question of Life,
        the Universe, and Everything: 42

Note, this build is not exactly what Nix builds, but is extremely close because we are using very close to the same environment Nix would use. We accept this compromise for developer conveniences, like incremental builds.

Regarding the “new-\*” commands, they've been released for testing by the Cabal development team. Once they've been deemed stable, the normal commands will be replaced with their “new-” counterparts, which will go away. In an effort to help to contribute towards these commands' success, we don't not shy from using them, and encourages people to try them out.

If you're familiar with Cabal sandboxes, you can use those too instead of the “new-\*” commands, but you will deviate from the integration of tools shown by these tutorials. Some things may break and require a different approach, so sandboxes are beyond the scope of this project. Also, sandboxes seem likely to go away with once the “new-\*” commands are officially released.


<a id="org66f1e64"></a>

## Accidentally building outside a Nix shell

As discussed, the version of GHC we get in our Nix shell comes integrated with all our project dependencies. These are all built and installed into `/nix/store` upon entering the shell.

Therefore, when using our Nix shell this way, we'll never have to compile and install binaries into our local `~/.cabal` directory, which should remain spartan:

```shell
tree ~/.cabal/packages
```

    /home/shajra/.cabal/packages
    └── hackage.haskell.org
        ├── 01-index.cache
        ├── 01-index.tar
        ├── 01-index.tar.gz
        ├── 01-index.tar.idx
        ├── 01-index.timestamp
        ├── hackage-security-lock
        ├── mirrors.json
        ├── root.json
        ├── snapshot.json
        └── timestamp.json
    
    1 directory, 10 files

If you call `cabal` outside of the Nix shell you'll see dependencies download from the internet and compile. This build will not use Nix at all, and use Cabal to resolve dependencies.

Of course, a simple way to avoid this problem altogether is to not install Cabal or GHC outside a Nix shell.

If you get confused about whether you've compiled with or without Nix, you can always delete the following folders and try again:

-   `~/.cabal/packages`
-   `~/.cabal/store`
-   `./dist-newstyle`
-   `./.ghc.environment.*`

These last `.ghc.environment.*` files are [a controversial file](https://github.com/haskell/cabal/issues/4542) generated by Cabal that saves state from build to build. Fortunately, Pkgs-make filters out this file for all Haskell builds so we don't have to think about it.


<a id="orgfb91a0e"></a>

## Ghcid

From `nix-shell` you can run `ghcid`, which some people like for fast incremental compilation while developing:

```text
nix-shell --run "ghcid --command 'cabal new-repl example-haskell-app'"
```

Ghcid will sense changes in source files, and automatically recompile them. However, the files sensed will only be for the package specified. For instance, because we specified a target of `example-haskell-app` above, Ghcid will sense changes to `application/src/Main.hs`, but not `library/src/Lib.hs`. We'd have to restart Ghcid to sense these changes.

Note, the reason Ghcid is faster than a normal build with Cabal or Stack is because, it's using a REPL session, which it uses to reload modules. This provides a faster compilation, but sometimes error messages get out of sync, and you have to restart Ghcid.


<a id="org031ddef"></a>

## Editor tags files

If you use a text editor like Emacs or Vim, you can navigate multiple projects fluidly using [Ctags/Etags](https://en.wikipedia.org/wiki/Ctags). For Haskell, this tutorial's Nix shell environment provides a `nix-tags-haskell` script to create a tags file:

```shell
nix-shell --run 'nix-tags-haskell --ctags --etags' 2>&1
```

    Cheking for stack with GNU which
    > which stack
    > which hasktags
    > find ./.stack-work ./stack ./.direnv ./application ./library -type f -and ( -name *\.hs -or -name *\.lhs -or -name *\.hsc )
    > cat ./application/.stack-work/dist/x86_64-linux-nix/Cabal-2.0.1.0/build/example-haskell/autogen/Paths_example_haskell_app.hs ./application/src/Main.hs ./library/.stack-work/dist/x86_64-linux-nix/Cabal-2.0.1.0/build/autogen/Paths_example_haskell_lib.hs ./library/src/FortyOne.lhs ./library/src/Lib.hs
    …
    Already unpacked protolude-0.2.2
    > find /home/shajra/.haskdogs/base-4.10.1.0 /home/shajra/.haskdogs/protolude-0.2.2 -type f -and ( -name *\.hs -or -name *\.lhs -or -name *\.hsc )
    > hasktags --follow-symlinks --ctags --etags ./application/.stack-work/dist/x86_64-linux-nix/Cabal-2.0.1.0/build/example-haskell/autogen/Paths_example_haskell_app.hs ./application/src/Main.hs ./library/.stack-work/dist/x86_64-linux-nix/Cabal-2.0.1.0/build/autogen/Paths_example_haskell_lib.hs ./library/src/FortyOne.lhs ./library/src/Lib.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Applicative.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Arrow.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Category.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Concurrent.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Concurrent/Chan.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Concurrent/MVar.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Concurrent/QSem.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Concurrent/QSemN.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Exception.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Exception/Base.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/Fail.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/Fix.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/IO/Class.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/Instances.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Imp.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Lazy.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Lazy/Imp.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Lazy/Safe.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Lazy/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Safe.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Strict.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/ST/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/Control/Monad/Zip.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Bifoldable.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Bifunctor.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Bitraversable.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Bits.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Bool.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Char.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Coerce.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Complex.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Data.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Dynamic.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Either.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Eq.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Fixed.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Foldable.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Function.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Classes.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Compose.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Const.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Identity.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Product.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Sum.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Functor/Utils.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/IORef.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Int.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Ix.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Kind.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/List.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/List/NonEmpty.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Maybe.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Monoid.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/OldList.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Ord.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Proxy.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Ratio.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/STRef.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/STRef/Lazy.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/STRef/Strict.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Semigroup.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/String.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Traversable.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Tuple.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Type/Bool.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Type/Coercion.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Type/Equality.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Typeable.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Typeable/Internal.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Unique.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Version.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Void.hs /home/shajra/.haskdogs/base-4.10.1.0/Data/Word.hs /home/shajra/.haskdogs/base-4.10.1.0/Debug/Trace.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/C.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/C/Error.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/C/String.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/C/Types.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Concurrent.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/ForeignPtr.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/ForeignPtr/Imp.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/ForeignPtr/Safe.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/ForeignPtr/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Alloc.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Array.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Error.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Pool.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Safe.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Marshal/Utils.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Ptr.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Safe.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/StablePtr.hs /home/shajra/.haskdogs/base-4.10.1.0/Foreign/Storable.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Arr.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Base.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Char.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Conc.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Conc/IO.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Conc/Signal.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Conc/Sync.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Conc/Windows.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/ConsoleHandler.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Constants.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Desugar.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Enum.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Environment.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Err.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Arr.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Array.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Clock.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Control.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/EPoll.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/IntTable.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Internal.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/KQueue.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Manager.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/PSQ.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Poll.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Thread.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/TimerManager.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Event/Unique.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Exception.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/ExecutionStack.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/ExecutionStack/Internal.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Exts.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Fingerprint.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Fingerprint/Type.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Float.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Float/ConversionUtils.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Float/RealFracMethods.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Foreign.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/ForeignPtr.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/GHCi.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Generics.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Buffer.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/BufferedIO.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Device.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/CodePage.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/CodePage/API.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/CodePage/Table.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/Failure.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/Iconv.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/Latin1.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/Types.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/UTF16.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/UTF32.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Encoding/UTF8.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Exception.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/FD.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Handle.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Handle/FD.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Handle/Internals.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Handle/Lock.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Handle/Text.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Handle/Types.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/IOMode.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IO/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IOArray.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/IORef.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Int.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/List.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/MVar.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Natural.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Num.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/OldList.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/OverloadedLabels.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/PArr.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Pack.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Profiling.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Ptr.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/RTS/Flags.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Read.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Real.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Records.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/ST.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/STRef.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Show.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Stable.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Stack.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Stack/CCS.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Stack/Types.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/StaticPtr.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/StaticPtr/Internal.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Stats.hsc /home/shajra/.haskdogs/base-4.10.1.0/GHC/Storable.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/TopHandler.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/TypeLits.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/TypeNats.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Unicode.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Weak.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Windows.hs /home/shajra/.haskdogs/base-4.10.1.0/GHC/Word.hs /home/shajra/.haskdogs/base-4.10.1.0/Numeric.hs /home/shajra/.haskdogs/base-4.10.1.0/Numeric/Natural.hs /home/shajra/.haskdogs/base-4.10.1.0/Prelude.hs /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime.hsc /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime/Posix/ClockGetTime.hsc /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime/Posix/RUsage.hsc /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime/Posix/Times.hsc /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime/Unsupported.hs /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime/Utils.hs /home/shajra/.haskdogs/base-4.10.1.0/System/CPUTime/Windows.hsc /home/shajra/.haskdogs/base-4.10.1.0/System/Console/GetOpt.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Environment.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Environment/ExecutablePath.hsc /home/shajra/.haskdogs/base-4.10.1.0/System/Exit.hs /home/shajra/.haskdogs/base-4.10.1.0/System/IO.hs /home/shajra/.haskdogs/base-4.10.1.0/System/IO/Error.hs /home/shajra/.haskdogs/base-4.10.1.0/System/IO/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Info.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Mem.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Mem/StableName.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Mem/Weak.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Posix/Internals.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Posix/Types.hs /home/shajra/.haskdogs/base-4.10.1.0/System/Timeout.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/ParserCombinators/ReadP.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/ParserCombinators/ReadPrec.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/Printf.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/Read.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/Read/Lex.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/Show.hs /home/shajra/.haskdogs/base-4.10.1.0/Text/Show/Functions.hs /home/shajra/.haskdogs/base-4.10.1.0/Type/Reflection.hs /home/shajra/.haskdogs/base-4.10.1.0/Type/Reflection/Unsafe.hs /home/shajra/.haskdogs/base-4.10.1.0/Unsafe/Coerce.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Debug.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Applicative.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Base.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Bifunctor.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Bool.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/CallStack.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Conv.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Either.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Error.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Exceptions.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Functor.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/List.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Monad.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Panic.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Safe.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Semiring.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Protolude/Show.hs /home/shajra/.haskdogs/protolude-0.2.2/src/Unsafe.hs
    
    Success

By default the Ctags-formatted file (used by Vim) is put in `tags` and the Etags file (used by Emacs) is put in `TAGS`. `nix-tags-haskell` provides some additional configuration you can see with the `--help` switch.

In Vim, you can now use `Ctrl-]` and `Ctrl-t` to jump to declarations, even in the source code for third-party projects and the standard/base libraries.

In Emacs, you can use the `find-tag` command, which is by default bound to `Meta-.`, and you can go back with `pop-tag-mark`, bound by default to `Meta-*`.

There are also a myriad of ways to configure various editors to run the tags-generation command on demand and/or as necessary.


<a id="orgb683f55"></a>

## Dante

If you're using Emacs, you can use [Dante][dante] as an alternative to Ghcid and Stack. Follow the official directions to install Dante in Emacs. To make Dante work with this project, you need to include a new entry in the \`dante-repl-command-line-methods-alist\`. Here's an illustration of how to do this using the popular [Projectile][projectile] Emacs package to determine the project's root directory (Projectile provides much more, though):

\`\`\`lisp (setq-default dante-repl-command-line-methods-alist \`( (styx . ,(lambda (root) (dante-repl-by-file root "styx.yaml" '("styx" "repl")))) (nix-new . ,(lambda (root) (dante-repl-by-file (projectile-project-root) "shell.nix" \`("nix-shell" "&#x2013;run" "cabal new-repl" ,(concat (projectile-project-root) "/shell.nix"))))) (stack . ,(lambda (root) (dante-repl-by-file root "stack.yaml" '("stack" "repl")))) (bare . ,(lambda (\_) '("cabal" "repl"))))) \`\`\`

The important part for this project is the "nix-new" entry. The other entries are so Dante will continue to work with other types of Haskell projects.

Emacs configured with tags and Dante provides an extremely rich "IDE"-like developer experience for Haskell.

Note that Dante (like Ghcid) uses a REPL for faster compilation than a normal Cabal or Stack build. So like Ghcid, its errors can fall out of sync with a true build, and you'll need to restart the session with \`M-x dante-restart\`.


<a id="orgc1b9c4f"></a>

## Haskell Stack

If you have Stack installed, you can run it from the root project:

```shell
stack build 2>&1
```

    example-haskell-lib-0.1.0.0: unregistering (local file changes: example-haskell-lib.cabal src/FortyOne.lhs src/Lib.hs)
    example-haskell-lib-0.1.0.0: configure (lib)
    example-haskell-lib-0.1.0.0: build (lib)
    example-haskell-lib-0.1.0.0: copy/register
    Building all executables for `example-haskell-app' once. After a successful build of all of them, only specified executables will be rebuilt.
    example-haskell-app-0.1.0.0: configure (exe)
    example-haskell-app-0.1.0.0: build (exe)
    example-haskell-app-0.1.0.0: copy/register
    Completed 2 action(s).
    Log files have been written to: /home/shajra/src/shajra/example-nix/tutorials/2-haskell/.stack-work/logs/

With Stack's `--file-watch` switch, Stack will rebuild the project when files change, similarly to Ghcid.

****WARNING****: This project uses Stack's [built-in support for Nix integration](https://docs.haskellstack.org/en/stable/nix_integration/). System dependencies for Stack come from the Nix configuration. But be aware that Stack manages Haskell dependencies (including GHC) independently using the *resolver* specified in the tutorial's [`stack.yaml`](./stack.yaml). When developing with Nix and Stack, it's up to you to make sure the versions used by Stack are congruent to those used by Nix.

****TODO****: How to mention Dante?


<a id="org9b37987"></a>

## Stack-less change-triggered builds

This tutorial's `nix-shell` environment provides a `cabal-new-watch` script that emulates `stack build --file-watch` but only using dependencies managed by Nix.

This is a true Cabal build, so it won't be as fast as Ghcid or Dante, but should be about as fast as a normal Stack build.
module FluentCI.Class where


import Effect (Effect)
import Effect.Aff (Aff)
import FluentCI.Cache as Cache
import FluentCI.Client as Client
import FluentCI.Devbox as Devbox
import FluentCI.Devenv as Devenv
import FluentCI.Directory as Directory
import FluentCI.Envhub as Envhub
import FluentCI.Flox as Flox
import FluentCI.Hermit as Hermit
import FluentCI.Mise as Mise
import FluentCI.Nix (NixArgs)
import FluentCI.Nix as Nix
import FluentCI.Pipeline as Pipeline
import FluentCI.Pixi as Pixi
import FluentCI.Pkgx as Pkgx
import FluentCI.Proto as Proto
import FluentCI.Secret as Secret
import FluentCI.Service as Service

class Id a where
  id :: a -> Aff String

instance Id Devbox.Devbox where
  id devbox = Devbox.id devbox

instance Id Devenv.Devenv where
  id devenv = Devenv.id devenv

instance Id Cache.Cache where
  id cache = Cache.id cache

instance Id Directory.Directory where
  id directory = Directory.id directory

instance Id Mise.Mise where
  id mise = Mise.id mise

instance Id Nix.Nix where
  id nix = Nix.id nix

instance Id Pixi.Pixi where
  id pixi = Pixi.id pixi

instance Id Pkgx.Pkgx where
  id pkgx = Pkgx.id pkgx

instance Id Flox.Flox where
  id flox = Flox.id flox

instance Id Pipeline.Pipeline where
  id pipeline = Pipeline.id pipeline

instance Id Service.Service where
  id service = Service.id service

instance Id Secret.Secret where
  id secret = Secret.id secret

instance Id Proto.Proto where
  id proto = Proto.id proto

instance Id Hermit.Hermit where
  id hermit = Hermit.id hermit

class Stderr a where
  stderr :: a -> Aff String

instance Stderr Pipeline.Pipeline where
  stderr pipeline = Pipeline.stderr pipeline

instance Stderr Mise.Mise where
  stderr mise = Mise.stderr mise

instance Stderr Devbox.Devbox where
  stderr devbox = Devbox.stderr devbox

instance Stderr Devenv.Devenv where
  stderr devenv = Devenv.stderr devenv

instance Stderr Nix.Nix where
  stderr nix = Nix.stderr nix

instance Stderr Pixi.Pixi where
  stderr pixi = Pixi.stderr pixi

instance Stderr Pkgx.Pkgx where
  stderr pkgx = Pkgx.stderr pkgx

instance Stderr Flox.Flox where
  stderr flox = Flox.stderr flox

instance Stderr Directory.Directory where
  stderr directory = Directory.stderr directory

instance Stderr Proto.Proto where
  stderr proto = Proto.stderr proto

instance Stderr Hermit.Hermit where
  stderr hermit = Hermit.stderr hermit


class Stdout a where
  stdout :: a -> Aff String

instance Stdout Pipeline.Pipeline where
  stdout pipeline = Pipeline.stdout pipeline

instance Stdout Mise.Mise where
  stdout mise = Mise.stdout mise

instance Stdout Devbox.Devbox where
  stdout devbox = Devbox.stdout devbox

instance Stdout Devenv.Devenv where
  stdout devenv = Devenv.stdout devenv

instance Stdout Nix.Nix where
  stdout nix = Nix.stdout nix

instance Stdout Pixi.Pixi where
  stdout pixi = Pixi.stdout pixi

instance Stdout Pkgx.Pkgx where
  stdout pkgx = Pkgx.stdout pkgx

instance Stdout Flox.Flox where
  stdout flox = Flox.stdout flox

instance Stdout Directory.Directory where
  stdout directory = Directory.stdout directory

instance Stdout Proto.Proto where
  stdout proto = Proto.stdout proto

instance Stdout Hermit.Hermit where
  stdout hermit = Hermit.stdout hermit

class AsService a where
  asService :: a -> String -> Effect Service.Service

instance AsService Devbox.Devbox where
  asService devbox name = Devbox.asService devbox name

instance AsService Devenv.Devenv where
  asService devenv name = Devenv.asService devenv name

instance AsService Nix.Nix where
  asService nix name = Nix.asService nix name

instance AsService Mise.Mise where
  asService mise name = Mise.asService mise name

instance AsService Pipeline.Pipeline where
  asService pipeline name = Pipeline.asService pipeline name

instance AsService Pixi.Pixi where
  asService pixi name = Pixi.asService pixi name

instance AsService Pkgx.Pkgx where
  asService pkgx = Pkgx.asService pkgx

instance AsService Flox.Flox where
  asService flox name = Flox.asService flox name

instance AsService Proto.Proto where
  asService proto name = Proto.asService proto name

instance AsService Hermit.Hermit where
  asService hermit name = Hermit.asService hermit name


class WaitOn a where
  waitOn :: a -> Int -> Int -> Effect a

instance WaitOn Devbox.Devbox where
  waitOn devbox port timeout = Devbox.waitOn devbox port timeout

instance WaitOn Devenv.Devenv where
  waitOn devenv port timeout = Devenv.waitOn devenv port timeout

instance WaitOn Nix.Nix where
  waitOn nix port timeout = Nix.waitOn nix port timeout

instance WaitOn Mise.Mise where
  waitOn mise port timeout = Mise.waitOn mise port timeout

instance WaitOn Pipeline.Pipeline where
  waitOn pipeline port timeout = Pipeline.waitOn pipeline port timeout

instance WaitOn Pixi.Pixi where
  waitOn pixi port timeout = Pixi.waitOn pixi port timeout

instance WaitOn Pkgx.Pkgx where
  waitOn pkgx port timeout = Pkgx.waitOn pkgx port timeout

instance WaitOn Flox.Flox where
  waitOn flox port timeout = Flox.waitOn flox port timeout

instance WaitOn Proto.Proto where
  waitOn proto port timeout = Proto.waitOn proto port timeout

instance WaitOn Hermit.Hermit where
  waitOn hermit port timeout = Hermit.waitOn hermit port timeout



class WithCache a where
  withCache :: a -> Cache.Cache -> Effect a

instance WithCache Devbox.Devbox where
  withCache devbox cache = Devbox.withCache devbox cache

instance WithCache Devenv.Devenv where
  withCache devenv cache = Devenv.withCache devenv cache

instance WithCache Nix.Nix where
  withCache nix cache = Nix.withCache nix cache

instance WithCache Mise.Mise where
  withCache mise cache = Mise.withCache mise cache

instance WithCache Pipeline.Pipeline where
  withCache pipeline cache = Pipeline.withCache pipeline cache

instance WithCache Pixi.Pixi where
  withCache pixi cache = Pixi.withCache pixi cache

instance WithCache Pkgx.Pkgx where
  withCache pkgx cache = Pkgx.withCache pkgx cache

instance WithCache Flox.Flox where
  withCache flox cache = Flox.withCache flox cache

instance WithCache Proto.Proto where
  withCache proto cache = Proto.withCache proto cache

instance WithCache Hermit.Hermit where
  withCache hermit cache = Hermit.withCache hermit cache


class WithEnvVariable a where
  withEnvVariable :: a -> String -> String -> Effect a

instance WithEnvVariable Devbox.Devbox where
  withEnvVariable devbox name value = Devbox.withEnvVariable devbox name value

instance WithEnvVariable Devenv.Devenv where
  withEnvVariable devenv name value = Devenv.withEnvVariable devenv name value

instance WithEnvVariable Nix.Nix where
  withEnvVariable nix name value = Nix.withEnvVariable nix name value

instance WithEnvVariable Mise.Mise where
  withEnvVariable mise name value = Mise.withEnvVariable mise name value

instance WithEnvVariable Pipeline.Pipeline where
  withEnvVariable pipeline name value = Pipeline.withEnvVariable pipeline name value

instance WithEnvVariable Pixi.Pixi where
  withEnvVariable pixi name value = Pixi.withEnvVariable pixi name value

instance WithEnvVariable Pkgx.Pkgx where
  withEnvVariable pkgx name value = Pkgx.withEnvVariable pkgx name value

instance WithEnvVariable Flox.Flox where
  withEnvVariable flox name value = Flox.withEnvVariable flox name value

instance WithEnvVariable Proto.Proto where 
  withEnvVariable proto name value = Proto.withEnvVariable proto name value

instance WithEnvVariable Hermit.Hermit where  
  withEnvVariable hermit name value = Hermit.withEnvVariable hermit name value


class WithExec a where
  withExec :: a -> Array String -> Effect a

instance WithExec Devbox.Devbox where
  withExec devbox args = Devbox.withExec devbox args

instance WithExec Devenv.Devenv where
  withExec devenv args = Devenv.withExec devenv args

instance WithExec Nix.Nix where
  withExec nix args = Nix.withExec nix args

instance WithExec Mise.Mise where
  withExec mise args = Mise.withExec mise args

instance WithExec Pipeline.Pipeline where
  withExec pipeline args = Pipeline.withExec pipeline args

instance WithExec Pixi.Pixi where
  withExec pixi args = Pixi.withExec pixi args

instance WithExec Pkgx.Pkgx where
  withExec pkgx args = Pkgx.withExec pkgx args

instance WithExec Flox.Flox where
  withExec flox args = Flox.withExec flox args

instance WithExec Directory.Directory where
  withExec directory args = Directory.withExec directory args

instance WithExec Proto.Proto where
  withExec proto args = Proto.withExec proto args

instance WithExec Hermit.Hermit where
  withExec hermit args = Hermit.withExec hermit args

class WithSecretVariable a where
  withSecretVariable :: a -> String -> Secret.Secret -> Effect a

instance WithSecretVariable Devbox.Devbox where
  withSecretVariable devbox name secret = Devbox.withSecretVariable devbox name secret

instance WithSecretVariable Devenv.Devenv where
  withSecretVariable devenv name secret = Devenv.withSecretVariable devenv name secret

instance WithSecretVariable Nix.Nix where
  withSecretVariable nix name secret = Nix.withSecretVariable nix name secret

instance WithSecretVariable Mise.Mise where
  withSecretVariable mise name secret = Mise.withSecretVariable mise name secret

instance WithSecretVariable Pipeline.Pipeline where
  withSecretVariable pipeline name secret = Pipeline.withSecretVariable pipeline name secret

instance WithSecretVariable Pixi.Pixi where
  withSecretVariable pixi name secret = Pixi.withSecretVariable pixi name secret

instance WithSecretVariable Pkgx.Pkgx where
  withSecretVariable pkgx name secret = Pkgx.withSecretVariable pkgx name secret

instance WithSecretVariable Flox.Flox where
  withSecretVariable flox name secret = Flox.withSecretVariable flox name secret

instance WithSecretVariable Proto.Proto where
  withSecretVariable proto name secret = Proto.withSecretVariable proto name secret

instance WithSecretVariable Hermit.Hermit where
  withSecretVariable hermit name secret = Hermit.withSecretVariable hermit name secret

class WithService a where
  withService :: a -> Service.Service -> Effect a

instance WithService Devbox.Devbox where
  withService devbox service = Devbox.withService devbox service

instance WithService Devenv.Devenv where
  withService devenv service = Devenv.withService devenv service

instance WithService Nix.Nix where
  withService nix service = Nix.withService nix service

instance WithService Mise.Mise where
  withService mise service = Mise.withService mise service

instance WithService Pipeline.Pipeline where
  withService pipeline service = Pipeline.withService pipeline service

instance WithService Pixi.Pixi where
  withService pixi service = Pixi.withService pixi service

instance WithService Pkgx.Pkgx where
  withService pkgx service = Pkgx.withService pkgx service

instance WithService Flox.Flox where
  withService flox service = Flox.withService flox service

instance WithService Proto.Proto where
  withService proto service = Proto.withService proto service

instance WithService Hermit.Hermit where
  withService hermit service = Hermit.withService hermit service

class WithWorkdir a where
  withWorkdir :: a -> String -> Effect a

instance WithWorkdir Devbox.Devbox where
  withWorkdir devbox path = Devbox.withWorkdir devbox path

instance WithWorkdir Devenv.Devenv where
  withWorkdir devenv path = Devenv.withWorkdir devenv path

instance WithWorkdir Nix.Nix where
  withWorkdir nix path = Nix.withWorkdir nix path

instance WithWorkdir Mise.Mise where
  withWorkdir mise path = Mise.withWorkdir mise path

instance WithWorkdir Pipeline.Pipeline where
  withWorkdir pipeline path = Pipeline.withWorkdir pipeline path

instance WithWorkdir Pixi.Pixi where
  withWorkdir pixi path = Pixi.withWorkdir pixi path

instance WithWorkdir Pkgx.Pkgx where
  withWorkdir pkgx path = Pkgx.withWorkdir pkgx path

instance WithWorkdir Flox.Flox where
  withWorkdir flox path = Flox.withWorkdir flox path

instance WithWorkdir Proto.Proto where
  withWorkdir proto path = Proto.withWorkdir proto path

instance WithWorkdir Hermit.Hermit where 
  withWorkdir hermit path = Hermit.withWorkdir hermit path

class Devbox a where
  devbox :: a -> Effect Devbox.Devbox

instance Devbox Pipeline.Pipeline where
  devbox pipeline = Pipeline.devbox pipeline

instance Devbox Directory.Directory where
  devbox directory = Directory.devbox directory

instance Devbox Client.Client where
  devbox client = Client.devbox client

class Mise a where
  mise :: a -> Effect Mise.Mise

instance Mise Pipeline.Pipeline where
  mise pipeline = Pipeline.mise pipeline

instance Mise Directory.Directory where
  mise directory = Directory.mise directory

instance Mise Client.Client where
  mise client = Client.mise client

class Nix a where
  nix :: a -> NixArgs -> Effect Nix.Nix

instance Nix Pipeline.Pipeline where
  nix pipeline args = Pipeline.nix pipeline args

instance Nix Directory.Directory where
  nix directory args  = Directory.nix directory args

instance Nix Client.Client where
  nix client args = Client.nix client args

class Pixi a where
  pixi :: a -> Effect Pixi.Pixi

instance Pixi Pipeline.Pipeline where
  pixi pipeline = Pipeline.pixi pipeline

instance Pixi Directory.Directory where
  pixi directory = Directory.pixi directory

instance Pixi Client.Client where
  pixi client = Client.pixi client

class Pkgx a where
  pkgx :: a -> Effect Pkgx.Pkgx

instance Pkgx Pipeline.Pipeline where
  pkgx pipeline = Pipeline.pkgx pipeline

instance Pkgx Directory.Directory where
  pkgx directory = Directory.pkgx directory

instance Pkgx Client.Client where
  pkgx client = Client.pkgx client

class Proto a where
  proto :: a -> Effect Proto.Proto

instance Proto Pipeline.Pipeline where
  proto pipeline = Pipeline.proto pipeline

instance Proto Directory.Directory where
  proto directory = Directory.proto directory

instance Proto Client.Client where
  proto client = Client.proto client

class Hermit a where
  hermit :: a -> Effect Hermit.Hermit

instance Hermit Pipeline.Pipeline where
  hermit pipeline = Pipeline.hermit pipeline

instance Hermit Directory.Directory where
  hermit directory = Directory.hermit directory

instance Hermit Client.Client where
  hermit client = Client.hermit client

class Flox a where
  flox :: a -> Effect Flox.Flox

instance Flox Pipeline.Pipeline where
  flox pipeline = Pipeline.flox pipeline

instance Flox Directory.Directory where
  flox directory = Directory.flox directory

instance Flox Client.Client where
  flox client = Client.flox client

class Devenv a where
  devenv :: a -> Effect Devenv.Devenv

instance Devenv Pipeline.Pipeline where
  devenv pipeline = Pipeline.devenv pipeline

instance Devenv Directory.Directory where
  devenv directory = Directory.devenv directory

instance Devenv Client.Client where
  devenv client = Client.devenv client

class Envhub a where
  envhub :: a -> Effect Envhub.Envhub

instance Envhub Pipeline.Pipeline where
  envhub pipeline = Pipeline.envhub pipeline

instance Envhub Directory.Directory where
  envhub directory = Directory.envhub directory

instance Envhub Client.Client where
  envhub client = Client.envhub client



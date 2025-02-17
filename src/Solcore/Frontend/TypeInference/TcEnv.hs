module Solcore.Frontend.TypeInference.TcEnv where 

import Data.List 
import Data.Map (Map)
import qualified Data.Map as Map

import Solcore.Frontend.Pretty.SolcorePretty
import Solcore.Frontend.Syntax
import Solcore.Frontend.TypeInference.NameSupply
import Solcore.Frontend.TypeInference.TcSubst
import Solcore.Frontend.TypeInference.TcUnify
import Solcore.Primitives.Primitives


-- definition of type environment  
type Arity = Int 
-- type constructor arity and names of constructors 
data TypeInfo 
  = TypeInfo {
      arity :: Arity         -- number of type parameters 
    , constrNames :: [Name]  -- list of data constructor names 
    , fieldNames :: [Name]   -- list of field names 
    } deriving (Eq, Ord, Show)

-- name of constructor and its scheme
type ConInfo = (Name, Scheme)
-- number of weak parameters and method names
type Method = Name 
type ClassInfo = (Arity, [Method])
type Table a = Map Name a 
-- typing environment 
type Env = Table Scheme
type ClassTable = Table ClassInfo
type TypeTable = Table TypeInfo
type Inst = Qual Pred 
type InstTable = Table [Inst] 

data TcEnv 
  = TcEnv {
      ctx :: Env               -- Variable environment
    , typeEnv :: TypeTable     -- Type environment
    , instEnv :: InstTable     -- Instance Environment
    , typeTable :: TypeTable   -- Type information environment 
    , classTable :: ClassTable -- Class information table
    , contract :: Maybe Name   -- current contract name 
                               -- used to type check calls.
    , subst :: Subst           -- Current substitution
    , nameSupply :: NameSupply -- Fresh name supply
    , logs :: [String]         -- Logging
    , enableLog :: Bool        -- Enable logging?
    , enableCoverage :: Bool   -- Enable coverage checking?
    , maxRecursionDepth :: Int -- max recursion depth in 
                               -- context reduction
    }

initTcEnv :: TcEnv 
initTcEnv = TcEnv primCtx 
                  primTypeEnv
                  primInstEnv
                  primTypeEnv
                  primClassEnv 
                  Nothing 
                  mempty 
                  namePool 
                  []
                  True 
                  True 
                  100

primCtx :: Env 
primCtx = Map.fromList [primAddWord, primEqWord] 

primTypeEnv :: TypeTable 
primTypeEnv = Map.empty 

primInstEnv :: InstTable
primInstEnv = Map.empty 

primClassEnv :: ClassTable 
primClassEnv = Map.empty 


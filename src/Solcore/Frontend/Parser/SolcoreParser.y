{
module Solcore.Frontend.Parser.SolcoreParser where

import Solcore.Frontend.Lexer.SolcoreLexer hiding (lexer)
import Solcore.Frontend.Syntax.Contract
import Solcore.Frontend.Syntax.Name
import Solcore.Frontend.Syntax.Stmt
import Solcore.Frontend.Syntax.Ty
import Solcore.Primitives.Primitives
}


%name parser CompilationUnit
%monad {Alex}{(>>=)}{return}
%tokentype { Token }
%error     { parseError }
%lexer {lexer}{Token _ TEOF}

%token
      identifier {Token _ (TIdent $$)}
      number     {Token _ (TNumber $$)}
      tycon      {Token _ (TTycon $$)}
      stringlit  {Token _ (TString $$)}
      'contract' {Token _ TContract}
      'import'   {Token _ TImport}
      'let'      {Token _ TLet}
      '='        {Token _ TEq}
      '.'        {Token _ TDot}
      'class'    {Token _ TClass}
      'instance' {Token _ TInstance}
      'data'     {Token _ TData}
      'type'     {Token _ TType}
      'match'    {Token _ TMatch}
      'function' {Token _ TFunction}
      'constructor' {Token _ TConstructor}
      'return'   {Token _ TReturn}
      'lam'      {Token _ TLam}
      ';'        {Token _ TSemi}
      ':'        {Token _ TColon}
      ','        {Token _ TComma}
      '->'       {Token _ TArrow}
      '_'        {Token _ TWildCard}
      '=>'       {Token _ TDArrow}
      '('        {Token _ TLParen}
      ')'        {Token _ TRParen}
      '{'        {Token _ TLBrace}
      '}'        {Token _ TRBrace}
      '['        {Token _ TLBrack}
      ']'        {Token _ TRBrack}
      '|'        {Token _ TBar}

%expect 0

%%
-- compilation unit definition 

CompilationUnit :: {CompUnit Name}
CompilationUnit : ImportList ContractList          { CompUnit $1 $2 } 

ImportList :: { [Import] }
ImportList : ImportList Import                     { $2 : $1 }
           | {- empty -}                           { [] }

Import :: { Import }
Import : 'import' QualName ';'                     { Import (QualName $2) }

ContractList :: {[Contract Name]}
ContractList : ContractList Contract               { $2 : $1 }
             | {- empty -}                         { [] }

-- contracts 

Contract :: { Contract Name }
Contract : 'contract' Con OptParam '{' DeclList '}' { Contract $2 $3 $5 }

DeclList :: { [Decl Name] }
DeclList : Decl DeclList                           { $1 : $2 }
         | {- empty -}                             { [] }

-- declarations 

Decl :: { Decl Name }
Decl : FieldDef                                    {FieldDecl $1}
     | DataDef                                     {DataDecl $1}
     | SymDef                                      {SymDecl $1}
     | ClassDef                                    {ClassDecl $1}
     | InstDef                                     {InstDecl $1}
     | Function                                    {FunDecl $1}
     | Constructor                                 {ConstrDecl $1}

-- fields 

FieldDef :: { Field Name }
FieldDef : Name ':' Type InitOpt ';'               {Field $1 $3 $4}

-- algebraic data types 

DataDef :: { DataTy }
DataDef : 'data' Con OptParam '=' Constrs          {DataTy $2 $3 $5}     

Constrs :: {[Constr]}
Constrs : Constr '|' Constrs                       {$1 : $3}
        | Constr                                   {[$1]}

Constr :: { Constr }
Constr : Con OptTypeParam                          { Constr $1 $2 }

-- type synonyms 

SymDef :: { TySym }
SymDef : 'type' Con OptParam '=' Type               {TySym $2 $3 $5}

-- class definitions 

ClassDef :: { Class Name }
ClassDef 
  : 'class' ContextOpt Var ':' Con OptParam ClassBody {Class $2 $5 $6 $3 $7}

ClassBody :: {[Signature Name]}
ClassBody : '{' Signatures '}'                     {$2}

OptParam :: { [Tyvar] }
OptParam :  '[' VarCommaList ']'                   {$2}
         | {- empty -}                             {[]}

VarCommaList :: { [Tyvar] }
VarCommaList : Var ',' VarCommaList                {$1 : $3} 
             | Var                                 {[$1]}

ContextOpt :: {[Pred]}
ContextOpt : {- empty -}                           {[]}
           | Context                               {$1}

Context :: {[Pred]}
Context : '[' ConstraintList ']' '=>'              { $2 }   

ConstraintList :: { [Pred] }
ConstraintList : Constraint ',' ConstraintList     {$1 : $3}
               | Constraint                        {[$1]}

Constraint :: { Pred }
Constraint : Type ':' Con OptTypeParam             {InCls $3 $1 $4} 

Signatures :: { [Signature Name] }
Signatures : Signature ';' Signatures              {$1 : $3}
           | {- empty -}                           {[]}

Signature :: { Signature Name}
Signature : 'function' Name ConOpt '(' ParamList ')' OptRetTy   {Signature $2 $3 $5 $7}

ConOpt :: {[Pred]}
ConOpt : {- empty -}                               {[]}
       | '[' ConstraintList ']'                    {$2}

ParamList :: { [Param Name] }
ParamList : Param                                  {[$1]}
          | Param  ',' ParamList                   {$1 : $3}
          | {- empty -}                            {[]}

Param :: { Param Name }
Param : Name ':' Type                              {Typed $1 $3}
      | Name                                       {Untyped $1}

-- instance declarations 

InstDef :: { Instance Name }
InstDef : 'instance' ContextOpt Type ':' Con OptTypeParam InstBody { Instance $2 $5 $6 $3 $7 }

OptTypeParam :: { [Ty] }
OptTypeParam : '[' TypeCommaList ']'          {$2}
             | {- empty -}                    {[]}

TypeCommaList :: { [Ty] }
TypeCommaList : Type ',' TypeCommaList             {$1 : $3}
              | Type                               {[$1]}

Functions :: { [FunDef Name] }
Functions : Function Functions                     {$1 : $2}
          | {- empty -}                            {[]}

InstBody :: {[FunDef Name]}
InstBody : '{' Functions '}'                       {$2}

-- Function declaration 

Function :: { FunDef Name }
Function : Signature Body {FunDef $1 $2}

OptRetTy :: { Maybe Ty }
OptRetTy : '->' Type                               {Just $2}
         | {- empty -}                             {Nothing}

-- Contract constructor 

Constructor :: { Constructor Name }
Constructor : 'constructor' '(' ParamList ')' Body {Constructor $3 $5}

-- Function body 

Body :: { [Stmt Name] }
Body : '{' StmtList '}'                            {$2} 

StmtList :: { [Stmt Name] }
StmtList : Stmt ';' StmtList                       {$1 : $3}
         | {- empty -}                             {[]}

-- Statements 


Stmt :: { Stmt Name }
Stmt : Expr '=' Expr                               {$1 := $3}
     | 'let' Name ':' Type InitOpt                 {Let $2 (Just $4) $5}
     | 'let' Name InitOpt                          {Let $2 Nothing $3}
     | Expr                                        {StmtExp $1}
     | 'return' Expr                               {Return $2}
     | 'match' MatchArgList '{' Equations  '}'     {Match $2 $4}

MatchArgList :: {[Exp Name]}
MatchArgList : Expr                                {[$1]}
             | Expr ',' MatchArgList               {$1 : $3}

InitOpt :: {Maybe (Exp Name)}
InitOpt : {- empty -}                              {Nothing}
        | '=' Expr                                 {Just $2}

-- Expressions 

Expr :: { Exp Name }
Expr : Name                                        {Var $1}
     | Con ConArgs                                 {Con $1 $2}
     | Literal                                     {Lit $1}
     | '(' Expr ')'                                {$2}
     | Expr '.' Name                               {FieldAccess $1 $3}
     | Expr '.' Name FunArgs                       {Call (Just $1) $3 $4}
     | Name FunArgs                                {Call Nothing $1 $2}
     | 'lam' '(' ParamList ')' Body                {Lam $3 $5} 

ConArgs :: {[Exp Name]}
ConArgs : '[' ExprCommaList ']'                    {$2}
        | {- empty -}                              {[]} 

FunArgs :: {[Exp Name]} 
FunArgs : '(' ExprCommaList ')'                    {$2}

ExprCommaList :: { [Exp Name] }
ExprCommaList : Expr                               {[$1]}
              | {- empty -}                        {[]}
              | Expr ',' ExprCommaList             {$1 : $3}

-- Pattern matching equations 

Equations :: { [([Pat], [Stmt Name])]}
Equations : Equation Equations                     {$1 : $2}
          | {- empty -}                            {[]}

Equation :: { ([Pat], [Stmt Name]) }
Equation : '|' PatCommaList '=>' StmtList          {($2, $4)}

PatCommaList :: { [Pat] }
PatCommaList : Pattern                             {[$1]}
             | Pattern ',' PatCommaList            {$1 : $3}

Pattern :: { Pat }
Pattern : Name                                     {PVar $1}
        | Con PatternList                          {PCon $1 $2}
        | '_'                                      {PWildcard}
        | Literal                                  {PLit $1}
        | '(' Pattern ')'                          {$2}

PatternList :: {[Pat]}
PatternList : '[' PatList ']'                      {$2}
            | {- empty -}                          {[]}

PatList :: { [Pat] }
PatList : Pattern                                  {[$1]}
        | Pattern ',' PatList                      {$1 : $3}

-- literals 

Literal :: { Literal }
Literal : number                                   {IntLit $ toInteger $1}
        | stringlit                                {StrLit $1}

-- basic type definitions 

Type :: { Ty }
Type : Con OptTypeParam                            {TyCon $1 $2}
     | Var                                         {TyVar  $1}
     | LamType                                     {uncurry funtype $1}

LamType :: {([Ty], Ty)}
LamType : '(' TypeCommaList ')' '->' Type          {($2, $5)}

Var :: { Tyvar }
Var : Name                                         {TVar $1}  

Con :: { Name }
Con : tycon                                        { Name $1 }

QualName :: { [Name] }  
QualName : Con                                     { [$1] }
         | QualName '.' Con                        { $3 : $1 }

Name :: { Name }
Name : identifier                                  { Name $1 }

{
parseError :: Token -> Alex a
parseError _ 
  = do 
        (AlexPn _ line column, _, _, _) <- alexGetInput
        alexError $ "Parse error at line " ++ show line ++ 
                    ", column " ++ show column

lexer :: (Token -> Alex a) -> Alex a 
lexer = (=<< alexMonadScan)
}

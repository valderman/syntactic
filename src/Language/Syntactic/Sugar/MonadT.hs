{-# LANGUAGE CPP #-}
{-# LANGUAGE UndecidableInstances #-}

#if __GLASGOW_HASKELL__ < 708
#define TYPEABLE Typeable1
#else
#define TYPEABLE Typeable
#endif

-- | 'Syntactic' instance for 'Remon' using 'BindingT' to handle variable binding

module Language.Syntactic.Sugar.MonadT where



import Control.Monad.Cont
import Data.Typeable

import Language.Syntactic
import Language.Syntactic.Functional
import Language.Syntactic.Sugar.BindingT ()



-- | One-layer sugaring of monadic actions
sugarMonad
    :: ( BindingT :<: sym
       , MONAD m  :<: sym
       , symT ~ Typed sym
       , TYPEABLE m
       , Typeable a
       )
    => ASTF symT (m a) -> Remon symT m (ASTF symT a)
sugarMonad ma = Remon $ cont $ sugarSymT Bind ma

instance
    ( Syntactic a
    , Domain a ~ symT
    , symT ~ Typed sym
    , BindingT :<: sym
    , MONAD m  :<: sym
    , TYPEABLE m
    , Typeable (Internal a)
    ) =>
      Syntactic (Remon symT m a)
  where
    type Domain (Remon symT m a)   = symT
    type Internal (Remon symT m a) = m (Internal a)
    desugar = desugarMonadT . fmap desugar
    sugar   = fmap sugar   . sugarMonad

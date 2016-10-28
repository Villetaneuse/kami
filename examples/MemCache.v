Require Import Ascii Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word Lib.Struct.
Require Import Kami.Syntax Kami.ParametricSyntax Kami.Semantics Kami.Notations Kami.SemFacts.
Require Import Kami.Wf Kami.Tactics Kami.Specialize Kami.Duplicate Kami.RefinementFacts.
Require Import Ex.Msi Ex.MemTypes Ex.RegFile Ex.L1Cache Ex.ChildParent Ex.MemDir.
Require Import Ex.Fifo Ex.NativeFifo Ex.FifoCorrect Kami.ParametricEquiv Kami.ParametricInline Ex.Names.

Set Implicit Arguments.

Section MemCache.
  Variables IdxBits TagBits LgNumDatas DataBytes: nat.
  Variable Id: Kind.

  Variable FifoSize: nat.
  Variable LgNumChildren: nat.

  Definition l1Cache := getMetaFromSinNat LgNumChildren (l1Cache IdxBits TagBits LgNumDatas DataBytes Id).
  Definition l1cs := getMetaFromSinNat LgNumChildren (@regFileS cs%string IdxBits Msi Default eq_refl).
  Definition l1tag :=
    getMetaFromSinNat LgNumChildren (@regFileS tag IdxBits (L1Cache.Tag TagBits) Default eq_refl).
  Definition l1line :=
    getMetaFromSinNat LgNumChildren (@regFileS line IdxBits
                                  (L1Cache.Line LgNumDatas DataBytes) Default eq_refl).

  Definition l1 := l1Cache +++ (l1cs +++ l1tag +++ l1line).

  Definition MIdxBits := IdxBits + TagBits.

  Definition fifoRqToP :=
    getMetaFromSinNat
      LgNumChildren (simpleFifoS rqToParent (rsz FifoSize) (Struct (RqToP MIdxBits Id))
                                 eq_refl).
  
  Definition fifoRsToP :=
    getMetaFromSinNat
      LgNumChildren (simpleFifoS rsToParent (rsz FifoSize)
                                 (Struct (RsToP MIdxBits LgNumDatas DataBytes)) eq_refl).
  Definition fifoFromP :=
    getMetaFromSinNat
      LgNumChildren (simpleFifoS fromParent (rsz FifoSize)
                                 (Struct (FromP MIdxBits LgNumDatas DataBytes Id))
                                 eq_refl).

  Definition l1C :=
    l1 +++ (fifoRqToP +++ fifoRsToP +++ fifoFromP).

  Definition childParent := childParent MIdxBits LgNumDatas DataBytes LgNumChildren Id.

  Definition fifoRqFromC :=
    fifoM rqFromChild (rsz FifoSize) (Struct (RqFromC MIdxBits LgNumChildren Id)) eq_refl.
  Definition fifoRsFromC :=
    simpleFifoM rsFromChild (rsz FifoSize)
                (Struct (RsFromC MIdxBits LgNumDatas DataBytes LgNumChildren)) eq_refl.
  Definition fifoToC := simpleFifoM toChild (rsz FifoSize)
                                    (Struct (ToC MIdxBits LgNumDatas
                                                 DataBytes LgNumChildren Id)) eq_refl.

  Definition childParentC := (childParent +++ (fifoRqFromC +++ fifoRsFromC +++ fifoToC))%kami.

  Definition memDir := memDir MIdxBits LgNumDatas DataBytes LgNumChildren Id.
  Definition mline := @regFileM mline MIdxBits (MemDir.Line LgNumDatas DataBytes)
                                Default eq_refl.
  Definition mdir := @regFileM mcs MIdxBits (MemDir.Dir LgNumChildren) Default eq_refl.

  Definition memDirC := (memDir +++ mline +++ mdir)%kami.

  Definition memCache := (l1C +++ childParentC +++ memDirC)%kami.

  (* For applying a substitution lemma *)
  Definition fifosInMemCache :=
    modFromMeta
      ((fifoRqToP +++ fifoRsToP +++ fifoFromP)
         +++ (fifoRqFromC +++ fifoRsFromC +++ fifoToC)).

  Definition othersInMemCache :=
    modFromMeta (l1 +++ childParent +++ memDirC).

  (* Fifos connecting processors and memCache; it's NOT the part of "memCache" *)
  Definition fifoRqFromProc :=
    getMetaFromSinNat LgNumChildren (@fifoS "rqFromProc" FifoSize
                                            (Struct (RqFromProc IdxBits TagBits
                                                                LgNumDatas DataBytes))
                                            eq_refl).
  Definition fifoRsToProc :=
    getMetaFromSinNat LgNumChildren (@simpleFifoS "rsToProc" FifoSize
                                                  (Struct (RsToProc DataBytes)) eq_refl).

End MemCache.

Hint Unfold MIdxBits: MethDefs.
Hint Unfold l1Cache l1cs l1tag l1line l1
     fifoRqToP fifoRsToP fifoFromP
     l1C
     childParent fifoRqFromC fifoRsFromC fifoToC childParentC
     memDir mline mdir memDirC memCache: ModuleDefs.

Section MemCacheNativeFifo.
  Variables IdxBits TagBits LgNumDatas DataBytes: nat.
  Variable Id: Kind.

  Variable LgNumChildren: nat.

  Definition nfifoRqToP :=
    getMetaFromSinNat LgNumChildren (@nativeSimpleFifoS
                                       rqToParent
                                       (Struct (RqToP (MIdxBits IdxBits TagBits)
                                                      Id))
                                            Default eq_refl).
  Definition nfifoRsToP :=
    getMetaFromSinNat LgNumChildren (@nativeSimpleFifoS
                                       rsToParent
                                       (Struct (RsToP (MIdxBits IdxBits TagBits)
                                                      LgNumDatas DataBytes))
                                       Default eq_refl).
  Definition nfifoFromP :=
    getMetaFromSinNat LgNumChildren (@nativeSimpleFifoS
                                       fromParent
                                       (Struct (FromP (MIdxBits IdxBits TagBits)
                                                      LgNumDatas DataBytes Id))
                                            Default eq_refl).

  Definition nl1C :=
    (l1 IdxBits TagBits LgNumDatas DataBytes Id LgNumChildren)
      +++ (nfifoRqToP +++ nfifoRsToP +++ nfifoFromP).

  Definition nfifoRqFromC :=
    @nativeFifoM rqFromChild (Struct (RqFromC (MIdxBits IdxBits TagBits)
                                              LgNumChildren Id))
                 Default eq_refl.
  
  Definition nfifoRsFromC :=
    @nativeSimpleFifoM rsFromChild (Struct (RsFromC (MIdxBits IdxBits TagBits)
                                                    LgNumDatas DataBytes LgNumChildren))
                       Default eq_refl.
  
  Definition nfifoToC :=
    @nativeSimpleFifoM toChild (Struct (ToC (MIdxBits IdxBits TagBits)
                                            LgNumDatas DataBytes LgNumChildren Id))
                       Default eq_refl.

  Definition nchildParentC :=
    ((childParent IdxBits TagBits LgNumDatas DataBytes Id LgNumChildren)
       +++ (nfifoRqFromC +++ nfifoRsFromC +++ nfifoToC))%kami.

  Definition nmemCache :=
    (nl1C +++ nchildParentC +++ (memDirC IdxBits TagBits LgNumDatas DataBytes Id LgNumChildren))%kami.

  (* For applying a substitution lemma *)
  Definition nfifosInNMemCache :=
    modFromMeta
      ((nfifoRqToP +++ nfifoRsToP +++ nfifoFromP)
         +++ (nfifoRqFromC +++ nfifoRsFromC +++ nfifoToC)).
  
End MemCacheNativeFifo.

Hint Unfold fifoRqFromProc fifoRsToProc
     nfifoRqToP nfifoRsToP nfifoFromP
     nl1C nfifoRqFromC nfifoRsFromC nfifoToC nchildParentC nmemCache: ModuleDefs.



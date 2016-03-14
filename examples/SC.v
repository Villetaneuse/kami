Require Import Ascii Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word Lib.Struct Lib.StringBound.
Require Import Lts.Syntax Lts.Semantics Lts.Renaming.

Set Implicit Arguments.

(* The SC module is defined as follows: SC = n * Pinst + Minst,
 * where Pinst denotes an instantaneous processor core
 * and Minst denotes an instantaneous memory.
 *)

(* Abstract ISA *)
Section DecExec.
  Variables opIdx addrSize valSize rfIdx: nat.

  Definition StateK := SyntaxKind (Vector (Bit valSize) rfIdx).
  Definition StateT (ty : FullKind -> Type) := ty StateK.

  Definition DecInstK := SyntaxKind (STRUCT {
    "opcode" :: Bit opIdx;
    "reg" :: Bit rfIdx;
    "addr" :: Bit addrSize;
    "value" :: Bit valSize
  }).
  Definition DecInstT (ty : FullKind -> Type) := ty DecInstK.

  Definition DecT := forall ty, StateT ty -> ty (SyntaxKind (Bit addrSize)) -> DecInstT ty.
  Definition ExecT := forall ty, StateT ty -> ty (SyntaxKind (Bit addrSize)) -> DecInstT ty ->
                      ty (SyntaxKind (Bit addrSize)) * StateT ty.
End DecExec.

(* The module definition for Minst with n ports *)
Section MemInst.
  Variable n : nat.
  Variable addrSize : nat.
  Variable dType : Kind.

  Definition atomK := STRUCT {
    "type" :: Bit 2;
    "addr" :: Bit addrSize;
    "value" :: dType
  }.

  Definition memLd : ConstT (Bit 2) := WO~0~0.
  Definition memSt : ConstT (Bit 2) := WO~0~1.

  Definition memInst := MODULE {
    Register "mem" : Vector dType addrSize <- Default

    with Repeat n as i {
      Method ("exec"__ i)(a : atomK) : atomK :=
        If (#a@."type" == $$memLd) then
          Read memv <- "mem";
          LET ldval <- #memv@[#a@."addr"];
          Ret (STRUCT { "type" ::= #a@."type"; "addr" ::= #a@."addr"; "value" ::= #ldval }
               :: atomK)
        else
          Read memv <- "mem";
          Write "mem" <- #memv@[ #a@."addr" <- #a@."value" ];
          Ret #a
        as na;
        Ret #na
    }
  }.
End MemInst.

Hint Unfold atomK memLd memSt : MethDefs.
Hint Unfold memInst : ModuleDefs.

(* The module definition for Pinst *)
Section ProcInst.
  Variables opIdx addrSize valSize rfIdx : nat.

  (* External abstract ISA: dec and exec *)
  Variable dec: DecT opIdx addrSize valSize rfIdx.
  Variable exec: ExecT opIdx addrSize valSize rfIdx.

  Definition getNextPc ty ppc st := fst (exec (fullType ty) st ppc (dec (fullType ty) st ppc)).
  Definition getNextState ty ppc st := snd (exec (fullType ty) st ppc (dec (fullType ty) st ppc)).

  Variables opLd opSt opHt: ConstT (Bit opIdx).

  Definition memAtomK := atomK addrSize (Bit valSize).

  Definition execCm := MethodSig "exec"(memAtomK) : memAtomK.
  Definition haltCm := MethodSig "HALT"(Bit 0) : Bit 0.

  Definition nextPc {ty} ppc st :=
    (Write "pc" <- #(getNextPc ty ppc st);
     Retv)%kami.

  Definition procInst := MODULE {
    Register "pc" : Bit addrSize <- Default
    with Register "rf" : Vector (Bit valSize) rfIdx <- Default

    with Rule "execLd" :=
      Read ppc <- "pc";
      Read st <- "rf";
      Assert #(dec _ st ppc)@."opcode" == $$opLd;
      Call ldRep <- execCm(STRUCT {  "type" ::= $$memLd;
                                     "addr" ::= #(dec _ st ppc)@."addr";
                                    "value" ::= $$Default });
      Write "rf" <- #st@[#(dec _ st ppc)@."reg" <- #ldRep@."value"];
      (nextPc ppc st)

    with Rule "execSt" :=
      Read ppc <- "pc";
      Read st <- "rf";
      Assert #(dec _ st ppc)@."opcode" == $$opSt;
      Call execCm(STRUCT {  "type" ::= $$memSt;
                            "addr" ::= #(dec _ st ppc)@."addr";
                           "value" ::= #(dec _ st ppc)@."value" });
      nextPc ppc st

    with Rule "execHt" :=
      Read ppc <- "pc";
      Read st <- "rf";
      Assert #(dec _ st ppc)@."opcode" == $$opHt;
      Call haltCm();
      Retv

    with Rule "execNm" :=
      Read ppc <- "pc";
      Read st <- "rf";
      Assert !(#(dec _ st ppc)@."opcode" == $$opLd
             || #(dec _ st ppc)@."opcode" == $$opSt
             || #(dec _ st ppc)@."opcode" == $$opHt);
      Write "rf" <- #(getNextState _ ppc st);
      nextPc ppc st

    (* with Rule "voidRule" := *)
    (*   Retv *)
  }.

End ProcInst.

Hint Unfold getNextPc getNextState memAtomK execCm haltCm nextPc : MethDefs.
Hint Unfold procInst : ModuleDefs.

Section SC.
  Variables opIdx addrSize valSize rfIdx : nat.

  Variable dec: DecT opIdx addrSize valSize rfIdx.
  Variable exec: ExecT opIdx addrSize valSize rfIdx.

  Variables opLd opSt opHt: ConstT (Bit opIdx).

  Variable n: nat.

  Definition pinst := procInst dec exec opLd opSt opHt.

  Definition pinsti (i: nat) := specializeMod pinst i.

  Fixpoint pinsts (i: nat): Modules :=
    match i with
      | O => pinsti O
      | S i' => ConcatMod (pinsti i) (pinsts i')
    end.
  
  Definition minst := memInst n addrSize (Bit valSize).

  Definition sc := ConcatMod (pinsts n) minst.

End SC.

Hint Unfold pinst pinsti pinsts minst sc : ModuleDefs.


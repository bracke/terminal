with AUnit.Assertions;
with Terminal.App.Bidi;
with Terminal.App.Render_Model;

procedure Bidi_Smoke is
   use AUnit.Assertions;
   package Bidi renames Terminal.App.Bidi;
   package RM renames Terminal.App.Render_Model;
   use type Bidi.Resolve_Status;
   use type Bidi.Paragraph_Direction;
   use type Bidi.Visual_Position_Array;
   use type Bidi.Embedding_Level_Array;
   use type RM.Text_Run_Direction;

   procedure Check_Permutation
     (Positions : Bidi.Visual_Position_Array)
   is
      Seen : array (0 .. Positions'Length - 1) of Boolean :=
        (others => False);
   begin
      for Position of Positions loop
         Assert (Position < Positions'Length, "BiDi position must be bounded");
         Assert (not Seen (Position), "BiDi positions must be unique");
         Seen (Position) := True;
      end loop;
   end Check_Permutation;
begin
   declare
      --  Hebrew letters surrounding a European-number sequence exercise W2,
      --  W7, I1/I2, and the final L2 reordering pass.
      Logical : constant Bidi.Codepoint_Array :=
        [16#05D0#, 16#05D1#, Character'Pos ('1'), Character'Pos ('2'),
         16#05D2#];
      Positions : Bidi.Visual_Position_Array (Logical'Range);
      Levels    : Bidi.Embedding_Level_Array (Logical'Range);
      Visual    : Bidi.Codepoint_Array (Logical'Range);
      Base      : Bidi.Paragraph_Direction;
      Status    : Bidi.Resolve_Status;
   begin
      Bidi.Resolve (Logical, Positions, Levels, Visual, Base, Status);
      Assert (Status = Bidi.Resolved, "mixed Hebrew/number resolution");
      Assert (Base = Bidi.Right_To_Left, "mixed Hebrew paragraph base");
      Check_Permutation (Positions);
      Assert
        (Positions = [4, 3, 1, 2, 0],
         "mixed Hebrew/number visual order");
      Assert
        (Levels = [1, 1, 2, 2, 1],
         "mixed Hebrew/number embedding levels");
   end;

   declare
      --  N0 paired-bracket resolution and L4 mirroring must both survive the
      --  Ada bridge; the renderer uses this visual scalar to reshape brackets.
      Logical : constant Bidi.Codepoint_Array :=
        [16#05D0#, Character'Pos ('('), Character'Pos ('A'),
         Character'Pos (')'), 16#05D1#];
      Positions : Bidi.Visual_Position_Array (Logical'Range);
      Levels    : Bidi.Embedding_Level_Array (Logical'Range);
      Visual    : Bidi.Codepoint_Array (Logical'Range);
      Base      : Bidi.Paragraph_Direction;
      Status    : Bidi.Resolve_Status;
   begin
      Bidi.Resolve (Logical, Positions, Levels, Visual, Base, Status);
      Assert (Status = Bidi.Resolved, "paired-bracket resolution");
      Assert (Base = Bidi.Right_To_Left, "paired-bracket paragraph base");
      Check_Permutation (Positions);
      Assert
        (Visual (Positions (2) + 1) = Character'Pos (')')
         and then Visual (Positions (4) + 1) = Character'Pos ('('),
         "paired brackets should be mirrored at odd levels");
   end;

   declare
      --  Isolate controls are retained in the logical stream so X5a/X6a and
      --  isolating-run-sequence rules apply around embedded LTR content.
      Logical : constant Bidi.Codepoint_Array :=
        [16#05D0#, 16#2066#, Character'Pos ('A'), Character'Pos ('1'),
         16#2069#, 16#05D1#];
      Positions : Bidi.Visual_Position_Array (Logical'Range);
      Levels    : Bidi.Embedding_Level_Array (Logical'Range);
      Visual    : Bidi.Codepoint_Array (Logical'Range);
      Base      : Bidi.Paragraph_Direction;
      Status    : Bidi.Resolve_Status;
   begin
      Bidi.Resolve (Logical, Positions, Levels, Visual, Base, Status);
      Assert (Status = Bidi.Resolved, "isolate resolution");
      Assert (Base = Bidi.Right_To_Left, "isolate paragraph base");
      Check_Permutation (Positions);
      Assert
        (Levels (1) mod 2 = 1 and then Levels (6) mod 2 = 1,
         "surrounding Hebrew must remain RTL");
      Assert
        (Levels (3) mod 2 = 0 and then Levels (4) mod 2 = 0,
         "LTR isolate contents must retain an even level");
   end;

   Assert
     (Bidi.Can_Join (Character'Pos ('a'), Character'Pos ('b')),
      "adjacent LTR cells should coalesce");
   Assert
     (Bidi.Can_Join (Character'Pos ('1'), Character'Pos ('2')),
      "adjacent European numbers should coalesce");
   Assert
     (Bidi.Can_Join (Character'Pos (' '), Character'Pos (' ')),
      "adjacent whitespace should coalesce");
   Assert
     (not Bidi.Can_Join (Character'Pos ('('), Character'Pos (')')),
      "paired brackets must remain distinct resolver inputs");
   Assert
     (Bidi.Direction_For (2) = RM.Direction_Left_To_Right
      and then Bidi.Direction_For (3) = RM.Direction_Right_To_Left,
      "embedding-level direction conversion");

   declare
      Logical : constant Bidi.Codepoint_Array := [1 => 16#110000#];
      Positions : Bidi.Visual_Position_Array (Logical'Range);
      Levels    : Bidi.Embedding_Level_Array (Logical'Range);
      Visual    : Bidi.Codepoint_Array (Logical'Range);
      Base      : Bidi.Paragraph_Direction;
      Status    : Bidi.Resolve_Status;
   begin
      Bidi.Resolve (Logical, Positions, Levels, Visual, Base, Status);
      Assert (Status = Bidi.Invalid_Input, "invalid Unicode scalar rejection");
   end;
end Bidi_Smoke;

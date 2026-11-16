with Interfaces.C;

package body Terminal.App.Bidi is
   package C renames Interfaces.C;
   use type C.int;

   type C_Codepoint_Array is
     array (Positive range <>) of aliased C.unsigned;
   pragma Convention (C, C_Codepoint_Array);
   type C_Position_Array is array (Positive range <>) of aliased C.int;
   pragma Convention (C, C_Position_Array);
   type C_Level_Array is
     array (Positive range <>) of aliased C.unsigned_char;
   pragma Convention (C, C_Level_Array);

   function C_Resolve
     (Logical           : access C.unsigned;
      Count             : C.int;
      Logical_To_Visual : access C.int;
      Levels            : access C.unsigned_char;
      Visual            : access C.unsigned;
      Base_Direction    : access C.int) return C.int
   with Import, Convention => C, External_Name => "terminal_bidi_resolve";

   function C_Join_Group (Codepoint : C.unsigned) return C.int
   with Import, Convention => C, External_Name => "terminal_bidi_join_group";

   procedure Resolve
     (Logical           : Codepoint_Array;
      Logical_To_Visual : out Visual_Position_Array;
      Levels            : out Embedding_Level_Array;
      Visual            : out Codepoint_Array;
      Base              : out Paragraph_Direction;
      Status            : out Resolve_Status)
   is
      Count : constant Natural := Logical'Length;
   begin
      Logical_To_Visual := (others => 0);
      Levels := (others => 0);
      Visual := (others => 0);
      Base := Left_To_Right;

      if Count = 0
        or else Logical_To_Visual'Length /= Count
        or else Levels'Length /= Count
        or else Visual'Length /= Count
        or else Count > Natural (C.int'Last)
      then
         Status := Invalid_Input;
         return;
      end if;

      declare
         Input       : C_Codepoint_Array (1 .. Count);
         Positions   : C_Position_Array (1 .. Count) := (others => 0);
         C_Levels    : C_Level_Array (1 .. Count) := (others => 0);
         C_Visual    : C_Codepoint_Array (1 .. Count) := (others => 0);
         C_Base      : aliased C.int := 0;
         Seen        : array (0 .. Count - 1) of Boolean := (others => False);
      begin
         for I in 1 .. Count loop
            if Logical (Logical'First + I - 1) > 16#10FFFF# then
               Status := Invalid_Input;
               return;
            end if;
            Input (I) := C.unsigned (Logical (Logical'First + I - 1));
         end loop;

         if C_Resolve
              (Input (1)'Access,
               C.int (Count),
               Positions (1)'Access,
               C_Levels (1)'Access,
               C_Visual (1)'Access,
               C_Base'Access) = 0
         then
            Status := Backend_Failure;
            return;
         end if;

         for I in 1 .. Count loop
            if Positions (I) < 0
              or else Positions (I) >= C.int (Count)
              or else Seen (Natural (Positions (I)))
            then
               Status := Backend_Failure;
               return;
            end if;
            Seen (Natural (Positions (I))) := True;
            Logical_To_Visual (Logical_To_Visual'First + I - 1) :=
              Natural (Positions (I));
            Levels (Levels'First + I - 1) := Natural (C_Levels (I));
            Visual (Visual'First + I - 1) := Natural (C_Visual (I));
         end loop;

         Base :=
           (if C_Base = 0 then Left_To_Right else Right_To_Left);
         Status := Resolved;
      end;
   end Resolve;

   function Can_Join (Left, Right : Natural) return Boolean is
      Left_Group  : C.int;
      Right_Group : C.int;
   begin
      if Left > 16#10FFFF# or else Right > 16#10FFFF# then
         return False;
      end if;
      Left_Group := C_Join_Group (C.unsigned (Left));
      Right_Group := C_Join_Group (C.unsigned (Right));
      return Left_Group /= 0 and then Left_Group = Right_Group;
   end Can_Join;

   function Direction_For
     (Level : Natural) return Terminal.App.Render_Model.Text_Run_Direction is
     (if Level mod 2 = 0
      then Terminal.App.Render_Model.Direction_Left_To_Right
      else Terminal.App.Render_Model.Direction_Right_To_Left);
end Terminal.App.Bidi;

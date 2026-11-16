with Interfaces.C;
with Interfaces.C.Strings;

package body Terminal.App.Platform_IME is
   package C renames Interfaces.C;
   package CStr renames Interfaces.C.Strings;
   use type C.int;
   use type CStr.chars_ptr;

   type Text_Callback is access procedure (Text : CStr.chars_ptr)
     with Convention => C;
   function Native_Initialize
     (Window : System.Address;
      Commit : Text_Callback;
      Preedit : Text_Callback) return C.int
   with Import, Convention => C, External_Name => "bracke_ime_initialize";
   procedure Native_Finalize
     with Import, Convention => C, External_Name => "bracke_ime_finalize";
   function Native_Process_Key
     (Scancode : C.int;
      Action : C.int;
      Modifiers : C.int) return C.int
   with Import, Convention => C, External_Name => "bracke_ime_process_key";
   procedure Native_Set_Focused (Focused : C.int)
   with Import, Convention => C, External_Name => "bracke_ime_set_focused";
   procedure Native_Set_Cursor
     (X, Y, Width, Height : C.int)
   with Import, Convention => C, External_Name => "bracke_ime_set_cursor";

   Max_Commits : constant := 64;
   type Commit_Array is array (Positive range 1 .. Max_Commits) of
     Wide_Wide_Character;
   protected State is
      procedure Set_Installed (Value : Boolean);
      function Is_Installed return Boolean;
      procedure Set_Preedit (Value : String);
      function Has_Preedit return Boolean;
      procedure Copy_Preedit
        (Value : out String; Length : out Natural);
      procedure Push (Value : Wide_Wide_Character);
      procedure Add_Suppression (Count : Natural);
      procedure Take_Suppression (Value : out Boolean);
      procedure Pop
        (Value : out Wide_Wide_Character; Available : out Boolean);
   private
      Installed_Flag : Boolean := False;
      Preedit_Length : Natural range 0 .. Max_Preedit_Bytes := 0;
      Preedit : String (1 .. Max_Preedit_Bytes) := (others => ASCII.NUL);
      Commits : Commit_Array := (others => Wide_Wide_Character'Val (0));
      Head : Positive range 1 .. Max_Commits := 1;
      Tail : Positive range 1 .. Max_Commits := 1;
      Count : Natural range 0 .. Max_Commits := 0;
      Suppress_Count : Natural range 0 .. Max_Commits := 0;
   end State;

   protected body State is
      procedure Set_Installed (Value : Boolean) is
      begin
         Installed_Flag := Value;
         if not Value then
            Preedit_Length := 0;
            Count := 0;
            Head := 1;
            Tail := 1;
            Suppress_Count := 0;
         end if;
      end Set_Installed;
      function Is_Installed return Boolean is (Installed_Flag);
      procedure Set_Preedit (Value : String) is
         Length : constant Natural :=
           Natural'Min (Value'Length, Max_Preedit_Bytes);
      begin
         Preedit := (others => ASCII.NUL);
         Preedit_Length := Length;
         if Length > 0 then
            Preedit (1 .. Length) :=
              Value (Value'First .. Value'First + Length - 1);
         end if;
      end Set_Preedit;
      function Has_Preedit return Boolean is (Preedit_Length > 0);
      procedure Copy_Preedit
        (Value : out String; Length : out Natural) is
      begin
         Length := Natural'Min (Preedit_Length, Value'Length);
         Value := (others => ASCII.NUL);
         if Length > 0 then
            Value (Value'First .. Value'First + Length - 1) :=
              Preedit (1 .. Length);
         end if;
      end Copy_Preedit;
      procedure Push (Value : Wide_Wide_Character) is
      begin
         if Count = Max_Commits then return; end if;
         Commits (Tail) := Value;
         Tail := (if Tail = Max_Commits then 1 else Tail + 1);
         Count := Count + 1;
      end Push;
      procedure Add_Suppression (Count : Natural) is
      begin
         Suppress_Count := Natural'Min
           (Max_Commits, Suppress_Count + Natural'Min (Count, Max_Commits));
      end Add_Suppression;
      procedure Take_Suppression (Value : out Boolean) is
      begin
         if Suppress_Count = 0 then
            Value := False;
            return;
         end if;
         Suppress_Count := Suppress_Count - 1;
         Value := True;
      end Take_Suppression;
      procedure Pop
        (Value : out Wide_Wide_Character; Available : out Boolean) is
      begin
         Available := Count > 0;
         if not Available then
            Value := Wide_Wide_Character'Val (0);
            return;
         end if;
         Value := Commits (Head);
         Head := (if Head = Max_Commits then 1 else Head + 1);
         Count := Count - 1;
      end Pop;
   end State;

   procedure On_Preedit (Text : CStr.chars_ptr) with Convention => C;
   procedure On_Preedit (Text : CStr.chars_ptr) is
   begin
      State.Set_Preedit
        (if Text = CStr.Null_Ptr then "" else CStr.Value (Text));
   exception
      when others => State.Set_Preedit ("");
   end On_Preedit;

   procedure On_Commit (Text : CStr.chars_ptr) with Convention => C;
   procedure On_Commit (Text : CStr.chars_ptr) is
      Value : constant String :=
        (if Text = CStr.Null_Ptr then "" else CStr.Value (Text));
      I : Natural := Value'First;
      Code : Natural;
      Needed : Natural;
      Minimum : Natural;
      Valid : Boolean;
   begin
      while I <= Value'Last loop
         Code := Character'Pos (Value (I));
         Valid := True;
         if Code < 16#80# then
            Needed := 1; Minimum := 0;
         elsif Code in 16#C2# .. 16#DF# then
            Needed := 2; Minimum := 16#80#; Code := Code mod 32;
         elsif Code in 16#E0# .. 16#EF# then
            Needed := 3; Minimum := 16#800#; Code := Code mod 16;
         elsif Code in 16#F0# .. 16#F4# then
            Needed := 4; Minimum := 16#10000#; Code := Code mod 8;
         else
            Needed := 1; Minimum := 0; Valid := False; Code := 16#FFFD#;
         end if;
         Valid := Valid and then I + Needed - 1 <= Value'Last;
         if Valid and then Needed > 1 then
            for J in 1 .. Needed - 1 loop
               declare
                  Byte : constant Natural := Character'Pos (Value (I + J));
               begin
                  if Byte not in 16#80# .. 16#BF# then Valid := False; exit; end if;
                  Code := Code * 64 + Byte mod 64;
               end;
            end loop;
         end if;
         if not Valid or else Code < Minimum or else Code > 16#10FFFF#
           or else Code in 16#D800# .. 16#DFFF#
         then
            Code := 16#FFFD#;
            Needed := 1;
         end if;
         State.Push (Wide_Wide_Character'Val (Code));
         I := I + Needed;
      end loop;
      State.Set_Preedit ("");
   exception
      when others => null;
   end On_Commit;

   procedure Initialize (Window : System.Address; Status : out Install_Status) is
      Result : constant C.int :=
        Native_Initialize (Window, On_Commit'Access, On_Preedit'Access);
   begin
      State.Set_Installed (Result = 1);
      Status := (if Result = 1 then Installed
                 elsif Result = -1 then Unsupported else Install_Failed);
   end Initialize;

   procedure Finalize is
   begin
      Native_Finalize;
      State.Set_Installed (False);
   end Finalize;

   function Active return Boolean is (State.Is_Installed);

   function Process_Key (Event : GLFW_Vulkan.Input.Key_Event) return Boolean is
      Mods : C.int := 0;
      Action : constant C.int :=
        (case Event.Action is
           when GLFW_Vulkan.Input.Press => 1,
           when GLFW_Vulkan.Input.Repeat => 2,
           when GLFW_Vulkan.Input.Release => 0);
      Result : C.int;
   begin
      if not Active then return False; end if;
      if Event.Modifiers.Shift then Mods := Mods + 1; end if;
      if Event.Modifiers.Control then Mods := Mods + 2; end if;
      if Event.Modifiers.Alt then Mods := Mods + 4; end if;
      if Event.Modifiers.Super then Mods := Mods + 8; end if;
      Result := Native_Process_Key (C.int (Event.Scancode), Action, Mods);
      if Result > 0 then
         State.Add_Suppression (Natural (Result));
      end if;
      return Result /= 0;
   end Process_Key;

   function Suppress_Next_GLFW_Character return Boolean is
      Result : Boolean;
   begin
      State.Take_Suppression (Result);
      return Result;
   end Suppress_Next_GLFW_Character;

   procedure Set_Focused (Focused : Boolean) is
   begin
      if Active then Native_Set_Focused (if Focused then 1 else 0); end if;
   end Set_Focused;

   procedure Set_Cursor_Rectangle (X, Y, Width, Height : Natural) is
      function Bound (Value : Natural) return C.int is
        (C.int (Natural'Min (Value, Natural (C.int'Last))));
   begin
      if Active then
         Native_Set_Cursor (Bound (X), Bound (Y), Bound (Width), Bound (Height));
      end if;
   end Set_Cursor_Rectangle;

   function Preedit_Active return Boolean is (State.Has_Preedit);
   function Preedit_Text return String is
      Value : String (1 .. Max_Preedit_Bytes);
      Length : Natural;
   begin
      State.Copy_Preedit (Value, Length);
      return (if Length = 0 then "" else Value (1 .. Length));
   end Preedit_Text;
   function Status_Label return String is
     (if Preedit_Active then "IME " & Preedit_Text & "_" else "");
   procedure Poll_Commit
     (Code_Point : out Wide_Wide_Character;
      Available  : out Boolean) is
   begin
      State.Pop (Code_Point, Available);
   end Poll_Commit;
end Terminal.App.Platform_IME;

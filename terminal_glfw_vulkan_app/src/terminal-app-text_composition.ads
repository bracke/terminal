package Terminal.App.Text_Composition is
   Max_Digits : constant := 6;
   Max_Status_Label_Length : constant := 32;

   type State is private;

   procedure Begin_Composition (Item : out State);
   procedure Cancel (Item : in out State);
   procedure Append (Item : in out State; Digit : Character);
   procedure Backspace (Item : in out State);
   procedure Commit
     (Item       : in out State;
      Code_Point : out Wide_Wide_Character;
      Valid      : out Boolean);

   function Active (Item : State) return Boolean;
   function Text (Item : State) return String;
   function Status_Label (Item : State) return String;

private
   subtype Digit_Count is Natural range 0 .. Max_Digits;
   type State is record
      Is_Active : Boolean := False;
      Length    : Digit_Count := 0;
      Buffer    : String (1 .. Max_Digits) := (others => '0');
   end record;
end Terminal.App.Text_Composition;

with Terminal.App.Key_Bindings;
with Terminal.App.Session_Profiles;

package Terminal.App.Command_Palette is
   Max_Query_Length : constant := 32;
   Max_Items : constant :=
     Terminal.App.Key_Bindings.Configurable_Action'Pos
       (Terminal.App.Key_Bindings.Configurable_Action'Last)
     - Terminal.App.Key_Bindings.Configurable_Action'Pos
       (Terminal.App.Key_Bindings.Configurable_Action'First)
     + 1 + Terminal.App.Session_Profiles.Max_Profiles;
   Max_Status_Length : constant := 160;

   type Choice_Kind is (Action_Choice, Profile_Choice);
   type Choice is record
      Kind          : Choice_Kind := Action_Choice;
      Action        : Terminal.App.Key_Bindings.Configurable_Action :=
        Terminal.App.Key_Bindings.Paste;
      Profile_Index : Natural range 0 .. Terminal.App.Session_Profiles.Max_Profiles := 0;
   end record;
   type State is private;

   procedure Enter
     (Value    : in out State;
      Profiles : Terminal.App.Session_Profiles.Registry);
   procedure Leave (Value : in out State);
   procedure Append (Value : in out State; Ch : Character);
   procedure Backspace (Value : in out State);
   procedure Move (Value : in out State; Offset : Integer);
   function Active (Value : State) return Boolean;
   function Match_Count (Value : State) return Natural;
   function Selected (Value : State) return Choice;
   function Status_Label (Value : State) return String;

private
   subtype Item_Index is Positive range 1 .. Max_Items;
   type Choice_Array is array (Item_Index) of Choice;
   type Match_Array is array (Item_Index) of Item_Index;
   type Label_Value is record
      Length : Natural range 0 .. 64 := 0;
      Text   : String (1 .. 64) := (others => ' ');
   end record;
   type Label_Array is array (Item_Index) of Label_Value;
   type State is record
      Enabled : Boolean := False;
      Query_Length : Natural range 0 .. Max_Query_Length := 0;
      Query : String (1 .. Max_Query_Length) := (others => ' ');
      Item_Count : Natural range 0 .. Max_Items := 0;
      Items : Choice_Array := (others => <>);
      Labels : Label_Array := (others => <>);
      Matches : Match_Array := (others => 1);
      Matches_Count : Natural range 0 .. Max_Items := 0;
      Current : Item_Index := 1;
   end record;
end Terminal.App.Command_Palette;

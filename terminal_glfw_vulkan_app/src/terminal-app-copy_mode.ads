with Terminal.Common;
with Terminal.Core;
with Terminal.App.Selection;

package Terminal.App.Copy_Mode is
   Max_Query_Length : constant := 128;

   type State is limited private;

   procedure Enter_Copy
     (Item : in out State;
      Core : Terminal.Core.Terminal);
   procedure Enter_Search
     (Item : in out State;
      Core : Terminal.Core.Terminal);
   procedure Leave (Item : in out State);

   function Active (Item : State) return Boolean;
   function Searching (Item : State) return Boolean;

   procedure Append
     (Item : in out State;
      Code : Terminal.Common.Code_Point);
   procedure Backspace (Item : in out State);
   procedure Toggle_Regex (Item : in out State);
   procedure Toggle_Case (Item : in out State);
   procedure Toggle_Whole_Word (Item : in out State);
   procedure Remember_Query (Item : in out State);
   procedure History_Move (Item : in out State; Direction : Integer);
   function Query_Length (Item : State) return Natural;
   function Status_Label (Item : State) return String;

   procedure Find
     (Item    : in out State;
      Core    : Terminal.Core.Terminal;
      Backward : Boolean := False;
      Restart : Boolean := False);
   function Match_Found (Item : State) return Boolean;
   procedure Apply_Match_Highlights
     (Item     : State;
      Snapshot : in out Terminal.Core.Render_Snapshot);

   procedure Move
     (Item      : in out State;
      Core      : Terminal.Core.Terminal;
      Row_Delta : Integer;
      Col_Delta : Integer);
   procedure Move_Page
     (Item      : in out State;
      Core      : Terminal.Core.Terminal;
      Direction : Integer);
   procedure Move_Row_Edge
     (Item : in out State;
      Core : Terminal.Core.Terminal;
      Last : Boolean);

   function Recommended_Offset
     (Item : State;
      Core : Terminal.Core.Terminal) return Natural;
   function Visible_Position
     (Item   : State;
      Core   : Terminal.Core.Terminal;
      Offset : Natural) return Terminal.App.Selection.Cell_Position;
   procedure Select_Cursor
     (Item      : State;
      Core      : Terminal.Core.Terminal;
      Offset    : Natural;
      Selection : in out Terminal.App.Selection.Selection_State;
      Extend    : Boolean := False);

private
   type Mode_Kind is (Inactive, Copying, Search_Input);
   subtype Query_Index is Positive range 1 .. Max_Query_Length;
   type Query_Array is array (Query_Index) of Terminal.Common.Code_Point;
   Max_History : constant := 16;
   type History_Entry is record
      Query : Query_Array := (others => 0);
      Count : Natural range 0 .. Max_Query_Length := 0;
   end record;
   type History_Array is array (Positive range 1 .. Max_History) of History_Entry;
   type State is limited record
      Mode             : Mode_Kind := Inactive;
      Query            : Query_Array := (others => 0);
      Query_Count      : Natural range 0 .. Max_Query_Length := 0;
      Absolute_Row     : Natural := 0;
      Column           : Positive := 1;
      Match_Last_Column : Positive := 1;
      Has_Match        : Boolean := False;
      Regex_Mode       : Boolean := False;
      Case_Sensitive   : Boolean := True;
      Whole_Word       : Boolean := False;
      Regex_Valid      : Boolean := True;
      Match_Total      : Natural := 0;
      Match_Index      : Natural := 0;
      History          : History_Array;
      History_Count    : Natural range 0 .. Max_History := 0;
      History_Position : Natural range 0 .. Max_History := 0;
   end record;
end Terminal.App.Copy_Mode;

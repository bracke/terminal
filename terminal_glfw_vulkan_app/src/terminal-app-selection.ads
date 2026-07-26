with Terminal.Core;

package Terminal.App.Selection is
   type Cell_Position is record
      Row : Positive := 1;
      Col : Positive := 1;
   end record;

   type Selection_State is limited private;

   function Cell_From_Pixels
     (X           : Float;
      Y           : Float;
      Cell_Width  : Positive;
      Cell_Height : Positive;
      Margin      : Natural;
      Rows        : Positive;
      Cols        : Positive) return Cell_Position;

   procedure Begin_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position);

   procedure Update_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position);

   procedure Extend_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position);

   procedure Select_Word
     (Selection : in out Selection_State;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Position  : Cell_Position);

   procedure Select_Line
     (Selection : in out Selection_State;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Position  : Cell_Position);

   procedure Finish_Selection
     (Selection : in out Selection_State;
      Position  : Cell_Position);

   procedure Clear (Selection : in out Selection_State);

   function Is_Active (Selection : Selection_State) return Boolean;
   function Has_Selection (Selection : Selection_State) return Boolean;

   function Selected_Text
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Selection : Selection_State) return String;

   procedure Apply_To_Snapshot
     (Snapshot  : in out Terminal.Core.Render_Snapshot;
      Selection : Selection_State);

private
   type Selection_State is limited record
      Active       : Boolean := False;
      Has_Range    : Boolean := False;
      Anchor       : Cell_Position;
      Focus        : Cell_Position;
   end record;
end Terminal.App.Selection;

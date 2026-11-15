with Terminal.App.Selection;
with Terminal.Core;

package Terminal.App.Hyperlinks is
   Max_Hover_Title_Length : constant := 512;
   Max_Link_Label_Length : constant := 256;
   Max_Status_Label_Length : constant := Max_Link_Label_Length + 18;
   Max_Link_Hints : constant := 64;

   type Activation_Status is
     (Ok,
      No_Link,
      Unsupported_URI,
      Launch_Failed);

   function Link_At
     (Snapshot : Terminal.Core.Render_Snapshot;
      Position : Terminal.App.Selection.Cell_Position)
      return Terminal.Core.Hyperlink;

   function Same_Link
     (Left  : Terminal.Core.Hyperlink;
      Right : Terminal.Core.Hyperlink) return Boolean;

   function Supported_URI (URI : String) return Boolean;

   function Link_Label (Link : Terminal.Core.Hyperlink) return String;
   function Status_Label (Link : Terminal.Core.Hyperlink) return String;
   function Activation_Status_Label (Status : Activation_Status) return String;
   function Hover_Title
     (Base_Title : String;
      Link       : Terminal.Core.Hyperlink) return String;

   procedure Activate
     (Link   : Terminal.Core.Hyperlink;
      Status : out Activation_Status);

   type Hint_State is limited private;
   procedure Begin_Hints
     (State    : in out Hint_State;
      Snapshot : Terminal.Core.Render_Snapshot);
   procedure Move_Hint (State : in out Hint_State; Offset : Integer);
   procedure Leave_Hints (State : in out Hint_State);
   function Hints_Active (State : Hint_State) return Boolean;
   function Hint_Count (State : Hint_State) return Natural;
   function Current_Hint_Link (State : Hint_State) return Terminal.Core.Hyperlink;
   function Current_Hint_First
     (State : Hint_State) return Terminal.App.Selection.Cell_Position;
   function Current_Hint_Last
     (State : Hint_State) return Terminal.App.Selection.Cell_Position;
   function Hint_Status_Label (State : Hint_State) return String;

private
   subtype Hint_Index is Positive range 1 .. Max_Link_Hints;
   type Hint_Entry is record
      Link  : Terminal.Core.Hyperlink;
      First : Terminal.App.Selection.Cell_Position;
      Last  : Terminal.App.Selection.Cell_Position;
   end record;
   type Hint_Array is array (Hint_Index) of Hint_Entry;
   type Hint_State is limited record
      Enabled : Boolean := False;
      Count   : Natural range 0 .. Max_Link_Hints := 0;
      Current : Hint_Index := 1;
      Items   : Hint_Array := (others => <>);
   end record;
end Terminal.App.Hyperlinks;

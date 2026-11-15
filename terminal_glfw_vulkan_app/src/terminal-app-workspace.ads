with Terminal.App.Sessions;

package Terminal.App.Workspace is
   Max_Path_Length : constant := 1_024;
   Max_Label_Length : constant := 32;
   Max_Command_Length : constant := 512;
   type Layout_Kind is (Single, Tabs, Panes);
   type Pane_Orientation is (Horizontal, Vertical);
   type IO_Status is (Not_Found, Loaded, Saved, Invalid_Data, IO_Error);

   type Bounded_Path is record
      Length : Natural range 0 .. Max_Path_Length := 0;
      Text   : String (1 .. Max_Path_Length) := (others => ' ');
   end record;
   type Bounded_Label is record
      Length : Natural range 0 .. Max_Label_Length := 0;
      Text   : String (1 .. Max_Label_Length) := (others => ' ');
   end record;
   type Bounded_Command is record
      Length : Natural range 0 .. Max_Command_Length := 0;
      Text   : String (1 .. Max_Command_Length) := (others => ' ');
   end record;
   type Workspace_Entry is record
      Working_Directory : Bounded_Path;
      Label             : Bounded_Label;
      Startup_Command   : Bounded_Command;
   end record;
   type Entry_Array is
     array (Terminal.App.Sessions.Session_Index) of Workspace_Entry;
   type State is record
      Layout      : Layout_Kind := Single;
      Count       : Terminal.App.Sessions.Session_Count := 1;
      Active      : Terminal.App.Sessions.Session_Index := 1;
      Orientation : Pane_Orientation := Horizontal;
      Entries     : Entry_Array := (others => <>);
   end record;

   procedure Set_Path (Value : out Bounded_Path; Text : String);
   procedure Set_Label (Value : out Bounded_Label; Text : String);
   procedure Set_Command (Value : out Bounded_Command; Text : String);
   function Path_Text (Value : Bounded_Path) return String;
   function Label_Text (Value : Bounded_Label) return String;
   function Command_Text (Value : Bounded_Command) return String;
   procedure Load (Path : String; Value : out State; Status : out IO_Status);
   procedure Save (Path : String; Value : State; Status : out IO_Status);
end Terminal.App.Workspace;

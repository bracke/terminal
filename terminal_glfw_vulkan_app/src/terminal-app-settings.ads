with Terminal.App.Config;
with Terminal.Common;

package Terminal.App.Settings is
   type State is limited private;

   procedure Enter (Item : in out State);
   procedure Leave (Item : in out State);
   function Active (Item : State) return Boolean;
   function Editing (Item : State) return Boolean;
   procedure Move (Item : in out State; Direction : Integer);
   procedure Adjust
     (Item      : in out State;
      Config    : in out Terminal.App.Config.Config;
      Direction : Integer;
      Changed   : out Boolean);
   procedure Begin_Edit (Item : in out State);
   procedure Append
     (Item : in out State; Code : Terminal.Common.Code_Point);
   procedure Backspace (Item : in out State);
   procedure Apply_Edit
     (Item     : in out State;
      Config   : in out Terminal.App.Config.Config;
      Accepted : out Boolean);
   procedure Set_Message (Item : in out State; Message : String);
   function Status_Label
     (Item : State; Config : Terminal.App.Config.Config) return String;

private
   type Setting_Item is
     (Theme, Follow_System_Theme, Font_Size, Wheel_Lines, Window_Opacity,
      Background_Blur, Content_Padding,
      Always_On_Top, Focus_Mode,
      Window_Decorations, Shell_Integration, Desktop_Notifications,
      Bell_Notifications, Completion_Notifications, Protected_Input,
      Default_Profile,
      Config_Line, Import_Config, Export_Config);
   Max_Line_Length : constant := 1_024;
   Max_Message_Length : constant := 128;
   type State is limited record
      Is_Active : Boolean := False;
      Is_Editing : Boolean := False;
      Current : Setting_Item := Theme;
      Line : String (1 .. Max_Line_Length) := (others => ' ');
      Line_Length : Natural range 0 .. Max_Line_Length := 0;
      Message : String (1 .. Max_Message_Length) := (others => ' ');
      Message_Length : Natural range 0 .. Max_Message_Length := 0;
   end record;
end Terminal.App.Settings;

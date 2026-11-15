with Ada.Strings;
with Ada.Strings.Fixed;
with Terminal.App.Session_Profiles;
with Terminal.App.Theme;

package body Terminal.App.Settings is
   use type Terminal.App.Config.Line_Status;
   procedure Enter (Item : in out State) is
   begin
      Item.Is_Active := True;
      Item.Is_Editing := False;
   end Enter;

   procedure Leave (Item : in out State) is
   begin
      Item.Is_Active := False;
      Item.Is_Editing := False;
   end Leave;

   function Active (Item : State) return Boolean is (Item.Is_Active);
   function Editing (Item : State) return Boolean is (Item.Is_Editing);

   procedure Move (Item : in out State; Direction : Integer) is
      Position : Integer := Setting_Item'Pos (Item.Current) + Direction;
      Count : constant Positive := Setting_Item'Pos (Setting_Item'Last) + 1;
   begin
      if not Item.Is_Editing and then Direction /= 0 then
         Position := Position mod Count;
         if Position < 0 then Position := Position + Count; end if;
         Item.Current := Setting_Item'Val (Position);
      end if;
   end Move;

   procedure Adjust
     (Item      : in out State;
      Config    : in out Terminal.App.Config.Config;
      Direction : Integer;
      Changed   : out Boolean)
   is
      use type Terminal.App.Theme.Theme_Name;
      Profiles : Natural;
      Current : Natural;
      Accepted : Boolean;
   begin
      Changed := Direction /= 0;
      case Item.Current is
         when Theme =>
            Config.Color_Theme := Terminal.App.Theme.Theme_Name'Val
              ((Terminal.App.Theme.Theme_Name'Pos (Config.Color_Theme)
                + Direction
                + Terminal.App.Theme.Theme_Name'Pos
                    (Terminal.App.Theme.Theme_Name'Last) + 1)
               mod (Terminal.App.Theme.Theme_Name'Pos
                      (Terminal.App.Theme.Theme_Name'Last) + 1));
         when Font_Size =>
            Config.Font_Pixel_Size := Positive
              (Integer'Max
                 (Terminal.App.Config.Min_Font_Pixel_Size,
                  Integer'Min
                    (Terminal.App.Config.Max_Font_Pixel_Size,
                     Config.Font_Pixel_Size + Direction)));
         when Wheel_Lines =>
            Config.Wheel_Scroll_Lines := Positive
              (Integer'Max
                 (1, Integer'Min
                   (Terminal.App.Config.Max_Wheel_Scroll_Lines,
                    Config.Wheel_Scroll_Lines + Direction)));
         when Desktop_Notifications =>
            Config.Desktop_Notifications := not Config.Desktop_Notifications;
         when Bell_Notifications =>
            Config.Bell_Notifications := not Config.Bell_Notifications;
         when Completion_Notifications =>
            Config.Command_Completion_Notifications :=
              not Config.Command_Completion_Notifications;
         when Default_Profile =>
            Profiles := Terminal.App.Session_Profiles.Count
              (Config.Session_Profiles);
            if Profiles = 0 then
               Changed := False;
            else
               Current := Terminal.App.Session_Profiles.Default_Index
                 (Config.Session_Profiles);
               if Current = 0 then
                  Current := (if Direction < 0 then Profiles else 1);
               else
                  Current := Natural
                    ((Integer (Current) - 1 + Direction + Integer (Profiles))
                     mod Integer (Profiles)) + 1;
               end if;
               Terminal.App.Session_Profiles.Set_Default
                 (Config.Session_Profiles,
                  Terminal.App.Session_Profiles.Name
                    (Terminal.App.Session_Profiles.Item
                      (Config.Session_Profiles, Current)),
                  Accepted);
               Changed := Accepted;
            end if;
         when Config_Line =>
            Changed := False;
      end case;
   end Adjust;

   procedure Begin_Edit (Item : in out State) is
   begin
      if Item.Current = Config_Line then
         Item.Is_Editing := True;
         Item.Line_Length := 0;
      end if;
   end Begin_Edit;

   procedure Append
     (Item : in out State; Code : Terminal.Common.Code_Point) is
   begin
      if Item.Is_Editing and then Code in 32 .. 126
        and then Item.Line_Length < Max_Line_Length
      then
         Item.Line_Length := Item.Line_Length + 1;
         Item.Line (Item.Line_Length) := Character'Val (Code);
      end if;
   end Append;

   procedure Backspace (Item : in out State) is
   begin
      if Item.Is_Editing and then Item.Line_Length > 0 then
         Item.Line (Item.Line_Length) := ' ';
         Item.Line_Length := Item.Line_Length - 1;
      end if;
   end Backspace;

   procedure Apply_Edit
     (Item     : in out State;
      Config   : in out Terminal.App.Config.Config;
      Accepted : out Boolean)
   is
      Status : Terminal.App.Config.Line_Status;
   begin
      Accepted := False;
      if not Item.Is_Editing or else Item.Line_Length = 0 then return; end if;
      Terminal.App.Config.Apply_Line
        (Config, Item.Line (1 .. Item.Line_Length), Status);
      Accepted := Status = Terminal.App.Config.Accepted;
      Set_Message
        (Item, Terminal.App.Config.Line_Status_Label (Status));
      if Accepted then Item.Is_Editing := False; end if;
   end Apply_Edit;

   procedure Set_Message (Item : in out State; Message : String) is
      Length : constant Natural := Natural'Min
        (Message'Length, Max_Message_Length);
   begin
      Item.Message := (others => ' ');
      Item.Message_Length := Length;
      if Length > 0 then
         Item.Message (1 .. Length) :=
           Message (Message'First .. Message'First + Length - 1);
      end if;
   end Set_Message;

   function Trim_Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Both));

   function On_Off (Value : Boolean) return String is
     (if Value then "on" else "off");

   function Status_Label
     (Item : State; Config : Terminal.App.Config.Config) return String
   is
      Profile_Index : constant Natural :=
        Terminal.App.Session_Profiles.Default_Index (Config.Session_Profiles);
      Value : constant String :=
        (case Item.Current is
           when Theme => Terminal.App.Theme.Image (Config.Color_Theme),
           when Font_Size => Trim_Image (Config.Font_Pixel_Size) & " px",
           when Wheel_Lines => Trim_Image (Config.Wheel_Scroll_Lines),
           when Desktop_Notifications => On_Off (Config.Desktop_Notifications),
           when Bell_Notifications => On_Off (Config.Bell_Notifications),
           when Completion_Notifications =>
             On_Off (Config.Command_Completion_Notifications),
           when Default_Profile =>
             (if Profile_Index = 0 then "none"
              else Terminal.App.Session_Profiles.Name
                (Terminal.App.Session_Profiles.Item
                   (Config.Session_Profiles, Profile_Index))),
           when Config_Line =>
             (if Item.Is_Editing
              then Item.Line (1 .. Item.Line_Length)
              else "press Enter; e.g. profile.work.command = tmux"));
      Name : constant String :=
        (case Item.Current is
           when Theme => "theme",
           when Font_Size => "font size",
           when Wheel_Lines => "wheel lines",
           when Desktop_Notifications => "desktop notifications",
           when Bell_Notifications => "bell notifications",
           when Completion_Notifications => "completion notifications",
           when Default_Profile => "default profile",
           when Config_Line => "config/profile line");
   begin
      if not Item.Is_Active then return ""; end if;
      return "SETTINGS " & Name & ": " & Value
        & (if Item.Message_Length = 0 then ""
           else " [" & Item.Message (1 .. Item.Message_Length) & "]")
        & "  (Up/Down item, Left/Right change)";
   end Status_Label;
end Terminal.App.Settings;

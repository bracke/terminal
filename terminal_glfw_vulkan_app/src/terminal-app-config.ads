with Terminal.App.Theme;
with Terminal.App.Key_Bindings;
with Terminal.App.Session_Profiles;
with Terminal.Common.Graphics_Limits;
with Terminal.App.Vulkan_Limits;

package Terminal.App.Config is
   Max_Status_Label_Length : constant := 128;
   Default_Scrollback_Limit : constant Natural := 10_000;
   Max_Scrollback_Limit : constant Natural := 100_000;
   Default_Wheel_Scroll_Lines : constant Positive := 3;
   Max_Wheel_Scroll_Lines : constant Positive := 100;
   Default_Window_Width : constant Positive := 960;
   Default_Window_Height : constant Positive := 600;
   Max_Window_Dimension : constant Positive := 16_384;
   Default_Startup_Rows : constant Positive := 24;
   Default_Startup_Cols : constant Positive := 80;
   Max_Startup_Dimension : constant Positive := 1_000;
   Min_Font_Pixel_Size : constant Positive := 6;
   Default_Font_Pixel_Size : constant Positive := 16;
   Max_Font_Pixel_Size : constant Positive := 96;
   Max_Font_Path_Length : constant := 512;
   subtype Font_Path_Length is Natural range 0 .. Max_Font_Path_Length;
   type Font_Path_Value is record
      Length : Font_Path_Length := 0;
      Text   : String (1 .. Max_Font_Path_Length) := (others => ASCII.NUL);
   end record;
   Max_Startup_Command_Length : constant := 512;
   subtype Startup_Command_Length is
     Natural range 0 .. Max_Startup_Command_Length;
   type Startup_Command_Value is record
      Length : Startup_Command_Length := 0;
      Text   : String (1 .. Max_Startup_Command_Length) := (others => ASCII.NUL);
   end record;
   Max_Graphics_Transaction_Bytes : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Transaction_Bytes;
   Max_Graphics_Pending_Events : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Pending_Events;
   Max_Graphics_Pending_Bytes : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Pending_Bytes;
   Max_Graphics_Deferred_Input_Bytes : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Deferred_Input_Bytes;
   Max_Graphics_Image_Objects : constant Positive :=
     Terminal.App.Max_Graphics_Image_Objects;
   Max_Graphics_Image_Bytes : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Image_Bytes;
   Max_Graphics_Placements : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Placements;
   Max_Graphics_Animation_Frames : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Animation_Frames;
   Max_Graphics_Pixel_Dimension : constant Positive :=
     Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;
   Max_Graphics_GPU_Atlas_Bytes : constant Positive :=
     Terminal.App.Vulkan_Limits.Max_Atlas_Bytes;
   Max_Graphics_GPU_Atlas_Dimension : constant Positive :=
     Terminal.App.Vulkan_Limits.Max_Atlas_Dimension;
   Min_Graphics_GPU_Atlas_Bytes : constant Positive :=
     Terminal.App.Vulkan_Limits.Min_Atlas_Bytes;
   Min_Graphics_GPU_Atlas_Dimension : constant Positive :=
     Terminal.App.Vulkan_Limits.Min_Atlas_Dimension;

   type Line_Status is
     (Accepted,
      Ignored_Blank,
      Ignored_Comment,
      Missing_Separator,
      Unknown_Key,
      Invalid_Value);

   type Config_Load_Status is
     (Config_Not_Checked,
      Config_Not_Found,
      Config_Loaded,
      Config_Invalid,
      Config_IO_Error);

   type Config is record
      Color_Theme : Terminal.App.Theme.Theme_Name :=
        Terminal.App.Theme.Default_Dark;
      Scrollback_Limit : Natural := Default_Scrollback_Limit;
      Wheel_Scroll_Lines : Positive := Default_Wheel_Scroll_Lines;
      Window_Width : Positive := Default_Window_Width;
      Window_Height : Positive := Default_Window_Height;
      Startup_Rows : Positive := Default_Startup_Rows;
      Startup_Cols : Positive := Default_Startup_Cols;
      Font_Path : Font_Path_Value := (others => <>);
      Font_Pixel_Size : Positive := Default_Font_Pixel_Size;
      Bindings : Terminal.App.Key_Bindings.Binding_Set :=
        Terminal.App.Key_Bindings.Defaults;
      Desktop_Notifications : Boolean := True;
      Bell_Notifications : Boolean := False;
      Command_Completion_Notifications : Boolean := False;
      Workspace_Path : Font_Path_Value := (others => <>);
      Restore_Workspace : Boolean := True;
      Save_Workspace : Boolean := True;
      Startup_Command : Startup_Command_Value := (others => <>);
      Session_Profiles : Terminal.App.Session_Profiles.Registry;
      Kitty_File_Transfer : Boolean := False;
      Kitty_Temporary_Transfer : Boolean := True;
      Kitty_Shared_Memory : Boolean := True;
      ITerm2_File_Downloads : Boolean := False;
      Graphics_Transaction_Bytes : Positive :=
        Max_Graphics_Transaction_Bytes;
      Graphics_Pending_Events : Positive := Max_Graphics_Pending_Events;
      Graphics_Pending_Bytes : Positive := Max_Graphics_Pending_Bytes;
      Graphics_Deferred_Input_Bytes : Positive :=
        Max_Graphics_Deferred_Input_Bytes;
      Graphics_Image_Objects : Positive := Max_Graphics_Image_Objects;
      Graphics_Image_Bytes : Positive := Max_Graphics_Image_Bytes;
      Graphics_Per_Image_Bytes : Positive := Max_Graphics_Image_Bytes;
      Graphics_Placements : Positive := Max_Graphics_Placements;
      Graphics_Animation_Frames : Positive :=
        Max_Graphics_Animation_Frames;
      Graphics_Pixel_Dimension : Positive := Max_Graphics_Pixel_Dimension;
      Graphics_GPU_Atlas_Bytes : Positive :=
        Terminal.App.Vulkan_Limits.Default_Atlas_Bytes;
      Graphics_GPU_Atlas_Dimension : Positive :=
        Terminal.App.Vulkan_Limits.Default_Atlas_Dimension;
      Load_Status : Config_Load_Status := Config_Not_Checked;
      Invalid_Line : Natural := 0;
      Invalid_Line_Status : Line_Status := Accepted;
   end record;

   procedure Apply_Line
     (C      : in out Config;
      Line   : String;
      Status : out Line_Status);
   procedure Apply_Line
     (C        : in out Config;
      Line     : String;
      Accepted : out Boolean);
   procedure Load_File
     (C                : in out Config;
      Path             : String;
      Missing_Is_Error : Boolean := True);
   procedure Load (C : out Config);
   procedure Set_Workspace_Path
     (C : in out Config; Path : String; Accepted : out Boolean);
   function Active_Theme (C : Config) return Terminal.App.Theme.Theme;
   function Font_Path_String (C : Config) return String;
   function Workspace_Path_String (C : Config) return String;
   function Startup_Command_String (C : Config) return String;
   function Image (C : Config) return String;
   function Line_Status_Label (Status : Line_Status) return String;
   function Status_Label (C : Config) return String;
end Terminal.App.Config;

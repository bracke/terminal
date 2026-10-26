with Terminal.App.Theme;
with Terminal.App.Vulkan_Submit;

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
   Max_Startup_Cells : constant Positive := 1_000;
   Max_Graphics_Transaction_Bytes : constant Positive := 8 * 1024 * 1024;
   Max_Graphics_Pending_Events : constant Positive := 4_096;
   Max_Graphics_Pending_Bytes : constant Positive := 16 * 1024 * 1024;
   Max_Graphics_Deferred_Input_Bytes : constant Positive := 16 * 1024 * 1024;
   Max_Graphics_Image_Objects : constant Positive :=
     Terminal.App.Max_Graphics_Image_Objects;
   Max_Graphics_Image_Bytes : constant Positive := 64 * 1024 * 1024;
   Max_Graphics_Placements : constant Positive := 16 * 1024;
   Max_Graphics_Animation_Frames : constant Positive := 4_096;
   Max_Graphics_Pixel_Dimension : constant Positive := 16_384;
   Max_Graphics_GPU_Atlas_Bytes : constant Positive :=
     Terminal.App.Vulkan_Submit.Max_Image_Atlas_Bytes;
   Max_Graphics_GPU_Atlas_Dimension : constant Positive :=
     Terminal.App.Vulkan_Submit.Max_Image_Atlas_Dimension;
   Min_Graphics_GPU_Atlas_Bytes : constant Positive :=
     Terminal.App.Vulkan_Submit.Min_Image_Atlas_Bytes;
   Min_Graphics_GPU_Atlas_Dimension : constant Positive :=
     Terminal.App.Vulkan_Submit.Min_Image_Atlas_Dimension;

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
      Graphics_GPU_Atlas_Bytes : Positive := 4 * 1024 * 1024;
      Graphics_GPU_Atlas_Dimension : Positive := 4_096;
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
   function Active_Theme (C : Config) return Terminal.App.Theme.Theme;
   function Image (C : Config) return String;
   function Line_Status_Label (Status : Line_Status) return String;
   function Status_Label (C : Config) return String;
end Terminal.App.Config;

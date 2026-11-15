with Ada.Exceptions;

package Terminal.App.Cleanup_Diagnostics is
   type Component is
     (Cleanup_Lifecycle,
      Session_Runtime,
      PTY_Backend,
      Session_Table,
      Snapshot_Cache,
      GLFW_Window,
      GLFW_Context,
      Theme_Transaction,
      Image_Install,
      Media_Decoder,
      Platform_Launcher,
      Renderer_State,
      Frame_Image_Storage,
      Vulkan_Context,
      Vulkan_Device,
      Vulkan_Presenter);
   type Failure_Counts is array (Component) of Natural;

   Max_Detail_Length : constant := 160;
   subtype Detail_Length is Natural range 0 .. Max_Detail_Length;
   type Failure_Detail is record
      Present : Boolean := False;
      Source  : Component := Session_Runtime;
      Operation_Length : Detail_Length := 0;
      Operation : String (1 .. Max_Detail_Length) := (others => ' ');
      Exception_Length : Detail_Length := 0;
      Exception_Name : String (1 .. Max_Detail_Length) := (others => ' ');
   end record;
   type Failure_Snapshot is record
      Counts : Failure_Counts := (others => 0);
      Detail : Failure_Detail := (others => <>);
   end record;

   procedure Note_Failure (Source : Component);
   procedure Note_Failure (Source : Component; Operation : String);
   procedure Note_Failure
     (Source    : Component;
      Occurrence : Ada.Exceptions.Exception_Occurrence;
      Operation : String);
   function Capture return Failure_Snapshot;
   function Total (Counts : Failure_Counts) return Natural;
   function Status_Label (State : Failure_Snapshot) return String;
end Terminal.App.Cleanup_Diagnostics;

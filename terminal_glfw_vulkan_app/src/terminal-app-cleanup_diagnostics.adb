with Ada.Strings;
with Ada.Strings.Fixed;

package body Terminal.App.Cleanup_Diagnostics is
   protected Counters is
      procedure Note (Source : Component);
      function Read return Failure_Counts;
   private
      Values : Failure_Counts := (others => 0);
   end Counters;

   protected body Counters is
      procedure Note (Source : Component) is
      begin
         if Values (Source) < Natural'Last then
            Values (Source) := Values (Source) + 1;
         end if;
      end Note;

      function Read return Failure_Counts is (Values);
   end Counters;

   procedure Note_Failure (Source : Component) is
   begin
      Counters.Note (Source);
   end Note_Failure;

   function Snapshot return Failure_Counts is (Counters.Read);

   function Total (Counts : Failure_Counts) return Natural is
      Result : Natural := 0;
   begin
      for Value of Counts loop
         if Value > Natural'Last - Result then
            return Natural'Last;
         end if;
         Result := Result + Value;
      end loop;
      return Result;
   end Total;

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   function Status_Label (Counts : Failure_Counts) return String is
   begin
      return
        "cleanup failures=" & Image (Total (Counts))
        & " runtime=" & Image (Counts (Session_Runtime))
        & " table=" & Image (Counts (Session_Table))
        & " snapshots=" & Image (Counts (Snapshot_Cache))
        & " window=" & Image (Counts (GLFW_Window))
        & " glfw=" & Image (Counts (GLFW_Context))
        & " theme=" & Image (Counts (Theme_Transaction))
        & " install=" & Image (Counts (Image_Install))
        & " renderer=" & Image (Counts (Renderer_State))
        & " frame_images=" & Image (Counts (Frame_Image_Storage))
        & " vk_context=" & Image (Counts (Vulkan_Context))
        & " vk_device=" & Image (Counts (Vulkan_Device))
        & " vk_presenter=" & Image (Counts (Vulkan_Presenter));
   end Status_Label;
end Terminal.App.Cleanup_Diagnostics;

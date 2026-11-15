with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Terminal.Common.Status;

package body Terminal.App.Cleanup_Diagnostics is
   protected Counters is
      procedure Increment (Source : Component);
      procedure Note
        (Source         : Component;
         Operation      : String;
         Exception_Name : String);
      function Capture return Failure_Snapshot;
   private
      Values : Failure_Counts := (others => 0);
      Detail : Failure_Detail;
   end Counters;

   protected body Counters is
      procedure Increment (Source : Component) is
      begin
         if Values (Source) < Natural'Last then
            Values (Source) := Values (Source) + 1;
         end if;
      end Increment;

      procedure Note
        (Source         : Component;
         Operation      : String;
         Exception_Name : String) is
         Operation_Count : constant Natural :=
           Natural'Min (Operation'Length, Max_Detail_Length);
         Exception_Count : constant Natural :=
           Natural'Min (Exception_Name'Length, Max_Detail_Length);
      begin
         if Values (Source) < Natural'Last then
            Values (Source) := Values (Source) + 1;
         end if;
         Detail := (Present => True, Source => Source, others => <>);
         Detail.Operation_Length := Operation_Count;
         Detail.Exception_Length := Exception_Count;
         if Operation_Count > 0 then
            Detail.Operation (1 .. Operation_Count) :=
              Operation
                (Operation'First .. Operation'First + Operation_Count - 1);
         end if;
         if Exception_Count > 0 then
            Detail.Exception_Name (1 .. Exception_Count) :=
              Exception_Name
                (Exception_Name'First
                 .. Exception_Name'First + Exception_Count - 1);
         end if;
      end Note;

      function Capture return Failure_Snapshot is
        ((Counts => Values, Detail => Detail));
   end Counters;

   procedure Note_Failure (Source : Component) is
   begin
      --  A count-only report must not erase more useful context retained from
      --  an earlier exception-aware cleanup path.
      Counters.Increment (Source);
   end Note_Failure;

   procedure Note_Failure (Source : Component; Operation : String) is
   begin
      Counters.Note (Source, Operation, "");
   end Note_Failure;

   procedure Note_Failure
     (Source     : Component;
      Occurrence : Ada.Exceptions.Exception_Occurrence;
      Operation  : String) is
   begin
      Counters.Note
        (Source, Operation, Ada.Exceptions.Exception_Name (Occurrence));
   end Note_Failure;

   function Capture return Failure_Snapshot is (Counters.Capture);

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
     (Terminal.Common.Status.Trimmed_Natural (Value));

   function Label (Value : Component) return String is
     (case Value is
         when Cleanup_Lifecycle   => "lifecycle",
         when Session_Runtime     => "runtime",
         when PTY_Backend         => "pty",
         when Session_Table       => "table",
         when Snapshot_Cache      => "snapshots",
         when GLFW_Window         => "window",
         when GLFW_Context        => "glfw",
         when Theme_Transaction   => "theme",
         when Image_Install       => "install",
         when Media_Decoder       => "media",
         when Platform_Launcher   => "launcher",
         when Renderer_State      => "renderer",
         when Frame_Image_Storage => "frame_images",
         when Vulkan_Context      => "vk_context",
         when Vulkan_Device       => "vk_device",
         when Vulkan_Presenter    => "vk_presenter");

   function Status_Label (State : Failure_Snapshot) return String is
      Counts : Failure_Counts renames State.Counts;
      Detail : Failure_Detail renames State.Detail;
      Detail_Text : constant String :=
        (if not Detail.Present
           or else
             (Detail.Operation_Length = 0 and then Detail.Exception_Length = 0)
         then ""
         elsif Detail.Operation_Length = 0
         then " detail=" & Label (Detail.Source) & ":"
           & Detail.Exception_Name (1 .. Detail.Exception_Length)
         else " detail=" & Label (Detail.Source) & ":"
           & Detail.Operation (1 .. Detail.Operation_Length)
           & (if Detail.Exception_Length = 0 then ""
              else ":" & Detail.Exception_Name (1 .. Detail.Exception_Length)));
      use Ada.Strings.Unbounded;
      Result : Unbounded_String := To_Unbounded_String
        ("cleanup failures=" & Image (Total (Counts)));
   begin
      for Source in Component loop
         Append
           (Result,
            " " & Label (Source) & "=" & Image (Counts (Source)));
      end loop;
      Append (Result, Detail_Text);
      return To_String (Result);
   end Status_Label;
end Terminal.App.Cleanup_Diagnostics;

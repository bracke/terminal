with Ada.Text_IO;

package body Terminal.App.Diagnostics is
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;

   Last_Initialized : Boolean := False;
   Last_Core : Terminal.Core.Diagnostic_Snapshot;
   Last_PTY_Overflows : Natural := 0;
   Last_Input_Overflows : Natural := 0;
   Last_Missing_Glyphs : Natural := 0;
   Last_Shaped_Glyphs : Natural := 0;
   Last_Shaping_Fallbacks : Natural := 0;
   Last_Render_Status : Terminal.App.Renderer.Render_Status :=
     Terminal.App.Renderer.Not_Initialized;
   Last_Presenter_Status : Terminal.App.Vulkan_Presenter.Present_Status :=
     Terminal.App.Vulkan_Presenter.Not_Initialized;
   Last_Accepted_Frames : Natural := 0;
   Last_Rejected_Frames : Natural := 0;
   Last_Atlas_Upload_Count : Natural := 0;

   procedure Put (Message : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "terminal: " & Message);
   end Put;

   function Collect
     (Core     : Terminal.Core.Terminal;
      PTY      : Terminal.App.Queues.PTY_Output_Queue;
      Input    : Terminal.App.Queues.Input_Event_Queue;
      Renderer : Terminal.App.Renderer.Renderer;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter)
      return Snapshot
   is
   begin
      return
        (Core            => Terminal.Core.Diagnostics (Core),
         PTY_Overflows   => PTY.Overflow_Count,
         Input_Overflows => Input.Overflow_Count,
         Renderer        => Terminal.App.Renderer.Diagnostics (Renderer),
         Presenter       => Terminal.App.Vulkan_Presenter.Diagnostics (Presenter));
   end Collect;

   procedure Log_Startup_Failure
     (Stage  : String;
      Status : String) is
   begin
      Put ("startup failed at " & Stage & ": " & Status);
   end Log_Startup_Failure;

   function Core_Changed (S : Snapshot) return Boolean is
   begin
      return S.Core.Malformed_UTF8 /= Last_Core.Malformed_UTF8
        or else S.Core.Ignored_Escape /= Last_Core.Ignored_Escape
        or else S.Core.Parser_Overflow /= Last_Core.Parser_Overflow
        or else S.Core.Queue_Overflow /= Last_Core.Queue_Overflow
        or else S.Core.Unsupported_Sequence /= Last_Core.Unsupported_Sequence
        or else
          S.Core.Text_Cluster_Overflow /= Last_Core.Text_Cluster_Overflow;
   end Core_Changed;

   function Queue_Changed (S : Snapshot) return Boolean is
   begin
      return S.PTY_Overflows /= Last_PTY_Overflows
        or else S.Input_Overflows /= Last_Input_Overflows;
   end Queue_Changed;

   function Renderer_Changed (S : Snapshot) return Boolean is
   begin
      return S.Renderer.Missing_Glyph_Count /= Last_Missing_Glyphs
        or else S.Renderer.Last_Shaped_Glyph_Count /= Last_Shaped_Glyphs
        or else
          S.Renderer.Last_Shaping_Fallback_Count /=
            Last_Shaping_Fallbacks
        or else S.Renderer.Last_Render_Status /= Last_Render_Status;
   end Renderer_Changed;

   function Presenter_Changed (S : Snapshot) return Boolean is
   begin
      return S.Presenter.Last_Status /= Last_Presenter_Status
        or else S.Presenter.Accepted_Frames /= Last_Accepted_Frames
        or else S.Presenter.Rejected_Frames /= Last_Rejected_Frames
        or else
          S.Presenter.Logical_Device.Atlas_Upload_Count /=
            Last_Atlas_Upload_Count;
   end Presenter_Changed;

   procedure Remember (S : Snapshot) is
   begin
      Last_Initialized := True;
      Last_Core := S.Core;
      Last_PTY_Overflows := S.PTY_Overflows;
      Last_Input_Overflows := S.Input_Overflows;
      Last_Missing_Glyphs := S.Renderer.Missing_Glyph_Count;
      Last_Shaped_Glyphs := S.Renderer.Last_Shaped_Glyph_Count;
      Last_Shaping_Fallbacks := S.Renderer.Last_Shaping_Fallback_Count;
      Last_Render_Status := S.Renderer.Last_Render_Status;
      Last_Presenter_Status := S.Presenter.Last_Status;
      Last_Accepted_Frames := S.Presenter.Accepted_Frames;
      Last_Rejected_Frames := S.Presenter.Rejected_Frames;
      Last_Atlas_Upload_Count :=
        S.Presenter.Logical_Device.Atlas_Upload_Count;
   end Remember;

   procedure Log_If_Changed (S : Snapshot) is
      Should_Log : constant Boolean :=
        not Last_Initialized
        or else Core_Changed (S)
        or else Queue_Changed (S)
        or else Renderer_Changed (S)
        or else Presenter_Changed (S);
   begin
      if not Should_Log then
         return;
      end if;

      Put
        ("diag"
         & " presenter=" &
           Terminal.App.Vulkan_Presenter.Present_Status'Image
             (S.Presenter.Last_Status)
         & " accepted=" & Natural'Image (S.Presenter.Accepted_Frames)
         & " rejected=" & Natural'Image (S.Presenter.Rejected_Frames)
         & " vertices=" & Natural'Image (S.Presenter.Last_Vertex_Count)
         & " atlas_uploads=" &
           Natural'Image (S.Presenter.Logical_Device.Atlas_Upload_Count)
         & " pty_overflows=" & Natural'Image (S.PTY_Overflows)
         & " input_overflows=" & Natural'Image (S.Input_Overflows)
         & " utf8_bad=" & Natural'Image (S.Core.Malformed_UTF8)
         & " parser_overflow=" & Natural'Image (S.Core.Parser_Overflow)
         & " unsupported=" & Natural'Image (S.Core.Unsupported_Sequence)
         & " cluster_overflow=" &
           Natural'Image (S.Core.Text_Cluster_Overflow)
         & " render=" &
           Terminal.App.Renderer.Render_Status'Image
             (S.Renderer.Last_Render_Status)
         & " missing_glyphs=" &
           Natural'Image (S.Renderer.Missing_Glyph_Count)
         & " shaped_glyphs=" &
           Natural'Image (S.Renderer.Last_Shaped_Glyph_Count)
         & " shaping_fallbacks=" &
           Natural'Image (S.Renderer.Last_Shaping_Fallback_Count));

      Remember (S);
   end Log_If_Changed;
end Terminal.App.Diagnostics;

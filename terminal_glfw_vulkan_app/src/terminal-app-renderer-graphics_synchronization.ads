with Terminal.Core;

private package Terminal.App.Renderer.Graphics_Synchronization is
   procedure Synchronize_Screen
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot);

   procedure Synchronize_Scroll
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Through  : Terminal.Core.Graphics_Scroll_Sequence);

   procedure Delete_Orphaned_Relative_Placements
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID := 0;
      Delete_Data       : Boolean := False);
end Terminal.App.Renderer.Graphics_Synchronization;

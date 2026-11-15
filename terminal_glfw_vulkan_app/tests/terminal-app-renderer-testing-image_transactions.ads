package Terminal.App.Renderer.Testing.Image_Transactions is
   procedure Verify_Index_Failure_Preserves_Placements
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID);
   procedure Verify_Delete_Rejection_Preserves_Placements
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID);
   procedure Verify_Placement_Preflight_Preserves_All
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID);
end Terminal.App.Renderer.Testing.Image_Transactions;

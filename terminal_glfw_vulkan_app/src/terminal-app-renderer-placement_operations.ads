with Terminal.App.Graphics;
with Terminal.App.Render_Model;
with Terminal.Core;

private package Terminal.App.Renderer.Placement_Operations is
   type Placement_Store_Status is
     (Placement_Not_Requested,
      Placement_Stored,
      Placement_Rejected,
      Placement_Parent_Missing,
      Placement_Cycle,
      Placement_Too_Deep,
      Placement_No_Space);

   type Relative_Placement_Status is
     (Relative_Valid,
      Relative_Parent_Missing,
      Relative_Cycle,
      Relative_Too_Deep);

   function To_Placement_Status
     (Status : Relative_Placement_Status) return Placement_Store_Status;

   function Store_Virtual_Placement
     (R         : in out Renderer;
      Event     : Terminal.Core.Graphics_Event;
      Header    : Terminal.App.Graphics.Graphics_Header;
      Prepared  : in out Virtual_Placement_Access)
      return Placement_Store_Status;

   function Validate_Relative_Placement
     (R                   : Renderer;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
      Child_Image_ID      : Terminal.Core.Graphics_ID;
      Child_Placement_ID  : Terminal.Core.Graphics_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID)
      return Relative_Placement_Status;

   function Resolve_Virtual_Placement_Origin
     (R            : Renderer;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Row          : out Integer;
      Col          : out Integer;
      Use_Index    : Boolean := False) return Boolean;

   function Resolve_Conventional_Placement_Origin
     (R         : Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Placement : Conventional_Placement_State;
      Row       : out Integer;
      Col       : out Integer;
      Use_Index : Boolean := False) return Boolean;

   function Store_Conventional_Placement
     (R        : in out Renderer;
      Event    : Terminal.Core.Graphics_Event;
      Header   : Terminal.App.Graphics.Graphics_Header;
      Prepared : in out Conventional_Placement_Access)
      return Placement_Store_Status;

   function Store_Auxiliary_Placement
     (R           : in out Renderer;
      Event       : Terminal.Core.Graphics_Event;
      Protocol    : Terminal.App.Render_Model.Image_Protocol;
      Draw_Width  : Positive;
      Draw_Height : Positive) return Boolean;
end Terminal.App.Renderer.Placement_Operations;

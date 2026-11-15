with Terminal.App.Image_Placements;
with Terminal.App.Image_Store;
with Terminal.App.Placeholder_Index;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_State;

package body Terminal.App.Renderer.Placement_Operations is
   package RM renames Terminal.App.Render_Model;
   package Image_Objects renames Terminal.App.Renderer.Image_Objects;
   package Placements_State renames Terminal.App.Renderer.Placement_State;

   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Placements.Conventional_Placement_Access;
   use type Terminal.Core.Graphics_ID;

   subtype Placement_Geometry is Placements_State.Placement_Geometry;

   function To_Placement_Status
     (Status : Relative_Placement_Status) return Placement_Store_Status is
     (case Status is
         when Relative_Valid          => Placement_Stored,
         when Relative_Parent_Missing => Placement_Parent_Missing,
         when Relative_Cycle          => Placement_Cycle,
         when Relative_Too_Deep       => Placement_Too_Deep);

   function Store_Virtual_Placement
     (R         : in out Renderer;
      Event     : Terminal.Core.Graphics_Event;
      Header    : Terminal.App.Graphics.Graphics_Header;
      Prepared  : in out Virtual_Placement_Access)
      return Placement_Store_Status is separate;

   function Validate_Relative_Placement
     (R                   : Renderer;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
      Child_Image_ID      : Terminal.Core.Graphics_ID;
      Child_Placement_ID  : Terminal.Core.Graphics_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID)
      return Relative_Placement_Status is separate;

   function Resolve_Virtual_Placement_Origin
     (R            : Renderer;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Row          : out Integer;
      Col          : out Integer;
      Use_Index    : Boolean := False) return Boolean is separate;

   function Resolve_Conventional_Placement_Origin
     (R         : Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Placement : Conventional_Placement_State;
      Row       : out Integer;
      Col       : out Integer;
      Use_Index : Boolean := False) return Boolean is separate;

   function Store_Conventional_Placement
     (R        : in out Renderer;
      Event    : Terminal.Core.Graphics_Event;
      Header   : Terminal.App.Graphics.Graphics_Header;
      Prepared : in out Conventional_Placement_Access)
      return Placement_Store_Status is separate;

   function Store_Auxiliary_Placement
     (R           : in out Renderer;
      Event       : Terminal.Core.Graphics_Event;
      Protocol    : RM.Image_Protocol;
      Draw_Width  : Positive;
      Draw_Height : Positive) return Boolean is separate;
end Terminal.App.Renderer.Placement_Operations;

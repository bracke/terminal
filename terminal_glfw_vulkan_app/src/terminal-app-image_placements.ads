with Interfaces;
with Terminal.App.Graphics;
with Terminal.App.Render_Model;
with Terminal.Core;

package Terminal.App.Image_Placements is
   type Virtual_Placement;
   type Virtual_Placement_Access is access Virtual_Placement;
   type Virtual_Placement is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID       : Terminal.Core.Graphics_ID := 0;
      Image_Storage_Order : Interfaces.Unsigned_64 := 0;
      Placement_ID   : Terminal.Core.Graphics_ID := 0;
      Columns        : Positive := 1;
      Rows           : Positive := 1;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Source_Width   : Natural := 0;
      Source_Height  : Natural := 0;
      Cell_X         : Natural := 0;
      Cell_Y         : Natural := 0;
      Draw_Offset_X  : Natural := 0;
      Draw_Offset_Y  : Natural := 0;
      Draw_Width     : Positive := 1;
      Draw_Height    : Positive := 1;
      Z_Index        : Integer := 0;
      Parent_Offset_X : Integer := 0;
      Parent_Offset_Y : Integer := 0;
      Next           : Virtual_Placement_Access := null;
   end record;

   type Conventional_Placement;
   type Conventional_Placement_Access is access Conventional_Placement;
   type Conventional_Placement is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID       : Terminal.Core.Graphics_ID := 0;
      Image_Storage_Order : Interfaces.Unsigned_64 := 0;
      Protocol       : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Placement_ID   : Terminal.Core.Graphics_ID := 0;
      Row            : Integer := 1;
      Col            : Positive := 1;
      Columns        : Positive := 1;
      Rows           : Positive := 1;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Source_Width   : Natural := 0;
      Source_Height  : Natural := 0;
      Cell_X         : Natural := 0;
      Cell_Y         : Natural := 0;
      Draw_Offset_X  : Natural := 0;
      Draw_Offset_Y  : Natural := 0;
      Draw_Width     : Positive := 1;
      Draw_Height    : Positive := 1;
      Z_Index        : Integer := 0;
      Parent_Image_ID : Terminal.Core.Graphics_ID := 0;
      Parent_Placement_ID : Terminal.Core.Graphics_ID := 0;
      Parent_Offset_X : Integer := 0;
      Parent_Offset_Y : Integer := 0;
      Scroll_Sequence : Terminal.Core.Graphics_Scroll_Sequence := 0;
      Clip_Top        : Natural := 0;
      Clip_Bottom     : Natural := 0;
      History_Attached : Boolean := False;
      Next           : Conventional_Placement_Access := null;
   end record;

   type Geometry is record
      Valid         : Boolean := False;
      Columns       : Positive := 1;
      Rows          : Positive := 1;
      Draw_Offset_X : Natural := 0;
      Draw_Offset_Y : Natural := 0;
      Draw_Width    : Positive := 1;
      Draw_Height   : Positive := 1;
   end record;

   function Resolve
     (Cell_Width   : Natural;
      Cell_Height  : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header       : Terminal.App.Graphics.Graphics_Header) return Geometry;
end Terminal.App.Image_Placements;

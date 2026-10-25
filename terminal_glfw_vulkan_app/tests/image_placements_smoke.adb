with Ada.Unchecked_Deallocation;
with AUnit.Assertions;

with Terminal.App.Graphics;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Store;
with Terminal.App.Placeholder_Index;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;

procedure Image_Placements_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;

   Header : Terminal.App.Graphics.Graphics_Header :=
     (Kitty_Columns_Specified => True,
      Kitty_Rows_Specified => True,
      Placeholder_Cols => 2,
      Placeholder_Rows => 2,
      others => <>);
   Geometry : Terminal.App.Image_Placements.Geometry :=
     Terminal.App.Image_Placements.Resolve
       (Cell_Width => 10,
        Cell_Height => 10,
        Pixel_Width => 20,
        Pixel_Height => 30,
        Header => Header);
begin
   Assert
     (Geometry.Valid
      and then Geometry.Columns = 2
      and then Geometry.Rows = 2
      and then Geometry.Draw_Width = 13
      and then Geometry.Draw_Height = 20
      and then Geometry.Draw_Offset_X = 3
      and then Geometry.Draw_Offset_Y = 0,
      "placement geometry preserves aspect ratio in its cell box");

   Header.Kitty_Source_X := 20;
   Geometry := Terminal.App.Image_Placements.Resolve
     (Cell_Width => 10,
      Cell_Height => 10,
      Pixel_Width => 20,
      Pixel_Height => 30,
      Header => Header);
   Assert
     (not Geometry.Valid,
      "placement geometry rejects an out-of-range source crop");

   declare
      package Placements renames Terminal.App.Image_Placements;
      package Store renames Terminal.App.Image_Store;
      Head : Placements.Virtual_Placement_Access :=
        new Placements.Virtual_Placement'
          (Stream_ID => 9, Image_ID => 7, Placement_ID => 2,
           Image_Storage_Order => 1, others => <>);
      Older : Placements.Virtual_Placement_Access :=
        new Placements.Virtual_Placement'
          (Stream_ID => 9, Image_ID => 7, Placement_ID => 1,
           Image_Storage_Order => 1, others => <>);
      Images : Store.Store;
      Object : Store.Image_Object_Access;
      Data : Terminal.App.Render_Model.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
      procedure Free is new Ada.Unchecked_Deallocation
        (Placements.Virtual_Placement,
         Placements.Virtual_Placement_Access);
   begin
      Head.Next := Older;
      Store.Create_Object (Object);
      Store.Link_New (Images, Object);
      Store.Install_Root
        (Images, Object,
         Stream_ID => 9, ID => 7, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Data);
      declare
         Index : Terminal.App.Placeholder_Index.Index;
      begin
         Terminal.App.Placeholder_Index.Build
           (Index, Head, Images, 9, False, 0);
         Assert
           (Terminal.App.Placeholder_Index.Find_Placement
              (Index, 7, 0) = Head
            and then Terminal.App.Placeholder_Index.Find_Placement
              (Index, 7, 1) = Older,
            "placeholder index preserves newest fallback and exact IDs");
         Assert
           (Terminal.App.Placeholder_Index.Find_Object (Index, 1) = Object,
            "placeholder index resolves image storage order");
      end;
      Free (Older);
      Free (Head);
   end;
end Image_Placements_Smoke;

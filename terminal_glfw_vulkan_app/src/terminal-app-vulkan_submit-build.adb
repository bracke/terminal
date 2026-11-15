separate (Terminal.App.Vulkan_Submit)
procedure Build
  (Frame  : RM.Frame_Commands;
   Batch  : in out Submission_Batch;
   Status : out Build_Status)
is
   Max_Vertices : Natural;

   type Image_Layer is
     (Image_Below_Cell_Background,
      Image_Below_Text,
      Image_Above_Text);

   Deep_Image_Threshold : constant Integer := -1_073_741_824;

   function In_Image_Layer
     (Image : RM.Image_Command;
      Layer : Image_Layer) return Boolean is
     (case Layer is
         when Image_Below_Cell_Background =>
           Image.Z_Index < Deep_Image_Threshold,
         when Image_Below_Text =>
           Image.Z_Index >= Deep_Image_Threshold
           and then Image.Z_Index < 0,
         when Image_Above_Text =>
           Image.Z_Index >= 0);

   function Image_Index_Less
     (Left  : Positive;
      Right : Positive) return Boolean
   is
      Left_Image  : RM.Image_Command renames Frame.Images (Left);
      Right_Image : RM.Image_Command renames Frame.Images (Right);
   begin
      return Left_Image.Z_Index < Right_Image.Z_Index
        or else
          (Left_Image.Z_Index = Right_Image.Z_Index
           and then
             (Left_Image.Image_ID < Right_Image.Image_ID
              or else
                (Left_Image.Image_ID = Right_Image.Image_ID
                 and then Left < Right)));
   end Image_Index_Less;

   procedure Sort_Image_Order is new Ada.Containers.Generic_Array_Sort
     (Index_Type   => Positive,
      Element_Type => Positive,
      Array_Type   => Image_Order_Array,
      "<"          => Image_Index_Less);

   procedure Prepare_Image_Order is
   begin
      if Frame.Image_Count = 0 then
         return;
      end if;
      if Batch.Image_Order = null
        or else Batch.Image_Order'Length < Frame.Image_Count
      then
         declare
            Replacement : Image_Order_Array_Access := new Image_Order_Array
              (1 .. Grown_Capacity
                ((if Batch.Image_Order = null
                  then 0
                  else Batch.Image_Order'Length),
                 Positive (Frame.Image_Count)));
         begin
            if Batch.Image_Order /= null then
               Free_Image_Order (Batch.Image_Order);
            end if;
            Batch.Image_Order := Replacement;
         end;
      end if;
      for I in 1 .. Frame.Image_Count loop
         Batch.Image_Order (I) := I;
      end loop;
      Batch.Image_Order_Total := Frame.Image_Count;
      if Frame.Image_Count > 1 then
         Sort_Image_Order (Batch.Image_Order (1 .. Batch.Image_Order_Total));
      end if;
   end Prepare_Image_Order;

   procedure Append_Image_Layer (Layer : Image_Layer) is
   begin
      for Position in 1 .. Batch.Image_Order_Total loop
         declare
            Image_Index : constant Positive := Batch.Image_Order (Position);
         begin
            if In_Image_Layer (Frame.Images (Image_Index), Layer) then
               Append_Image_Command
                 (Frame, Batch, Frame.Images (Image_Index));
            end if;
         end;
      end loop;
   end Append_Image_Layer;

   procedure Append_Rectangle_Layer (Layer : RM.Rectangle_Layer) is
   begin
      for I in 1 .. Frame.Rectangle_Count loop
         if Frame.Rectangles (I).Layer = Layer then
            declare
               Rect : constant RM.Rectangle_Command := Frame.Rectangles (I);
               Before : constant Natural := Batch.Count;
            begin
               Append_Quad
                 (Batch, Frame.Width, Frame.Height,
                  Rect.X, Rect.Y, Rect.Width, Rect.Height,
                  0.0, 0.0, 0.0, 0.0, Rect.Color, False, Texture_None);
               Batch.Rectangle_Vertex_Total :=
                 Batch.Rectangle_Vertex_Total + (Batch.Count - Before);
            end;
         end if;
      end loop;
   end Append_Rectangle_Layer;
begin
   Reset (Batch);

   if not Validation.Is_Valid (Frame) then
      Status := Invalid_Frame;
      return;
   end if;

   Max_Vertices := Validation.Vertex_Capacity (Frame);
   if Max_Vertices = 0 then
      Batch.Frame_Width := Frame.Width;
      Batch.Frame_Height := Frame.Height;
      Publish_Text_Atlas (Frame, Batch);
      Copy_Text_Runs (Frame, Batch);
      Status := Ok;
      return;
   end if;

   if Batch.Items = null or else Batch.Items'Length < Max_Vertices then
      declare
         Replacement : Vertex_Array_Access :=
           new Vertex_Array
             (1 .. Grown_Capacity
               ((if Batch.Items = null then 0 else Batch.Items'Length),
                Positive (Max_Vertices)));
      begin
         if Batch.Items /= null then
            Free_Vertices (Batch.Items);
         end if;
         Batch.Items := Replacement;
      end;
   end if;
   Copy_Text_Runs (Frame, Batch);
   Batch.Frame_Width := Frame.Width;
   Batch.Frame_Height := Frame.Height;
   Publish_Text_Atlas (Frame, Batch);
   Prepare_Image_Order;
   Prepare_Image_Atlas (Frame, Batch);

   Append_Rectangle_Layer (RM.Rectangle_Base_Background);
   Append_Image_Layer (Image_Below_Cell_Background);
   Append_Rectangle_Layer (RM.Rectangle_Cell_Background);
   Append_Image_Layer (Image_Below_Text);
   Append_Rectangle_Layer (RM.Rectangle_Foreground);

   for I in 1 .. Frame.Glyph_Count loop
      declare
         Glyph : constant RM.Glyph_Command := Frame.Glyphs (I);
         Before : constant Natural := Batch.Count;
      begin
         Append_Quad
           (Batch,
            Frame.Width,
            Frame.Height,
            Glyph.X,
            Glyph.Y,
            Glyph.Width,
            Glyph.Height,
            Glyph.U0,
            Glyph.V0,
            Glyph.U1,
            Glyph.V1,
            Glyph.Color,
            True,
            Texture_Text_Atlas);
         Batch.Glyph_Vertex_Total :=
           Batch.Glyph_Vertex_Total + (Batch.Count - Before);
         if Batch.Count > Before then
            Batch.Uses_Text_Atlas := True;
         end if;
      end;
   end loop;

   Publish_Colour_Atlas (Frame, Batch);

   Append_Colour_Glyphs (Frame, Batch);
   Append_Image_Layer (Image_Above_Text);

   for I in 1 .. Natural'Min
     (Batch.Last_Image_Decoded_Preview_Length,
      RM.Max_Image_Decoded_Preview_Length)
   loop
      Batch.Last_Image_Decoded_Preview_Bytes (I) :=
        RM.Image_Decoded_Preview_Byte (Batch.Last_Image_Row_Source, I);
   end loop;
   if Batch.Last_Image_Texture_Source /= Texture_Image then
      Batch.Last_Image_Row_Source := (others => <>);
   end if;

   Status := (if Batch.Vertex_Overflowed then Capacity_Exceeded else Ok);
exception
   when Storage_Error =>
      Release (Batch);
      Status := Allocation_Failed;
end Build;

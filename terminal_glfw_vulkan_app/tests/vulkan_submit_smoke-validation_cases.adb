separate (Vulkan_Submit_Smoke)
procedure Validation_Cases is
begin
   Reset_Fixture;
   declare
      Stale : RM.Frame_Commands := Frame;
   begin
      Stale.Glyphs := null;
      Stale.Glyph_Count := 0;
      Stale.Atlas_Pixels := Atlas_Data'Address;
      Stale.Atlas_Bytes := Natural'Last;
      Stale.Colour_Glyphs := null;
      Stale.Colour_Glyph_Count := 0;
      Stale.Colour_Sheet_Width := Natural'Last;
      Stale.Colour_Sheet_Height := Natural'Last;
      Stale.Colour_Sheet_Pixels := Atlas_Data'Address;
      VS.Build (Stale, Batch, Status);
      Assert
        (Status = VS.Ok
         and then VS.Atlas_Bytes (Batch) = 0
         and then not VS.Has_Atlas_Pixels (Batch)
         and then VS.Colour_Atlas_Bytes (Batch) = 0
         and then not VS.Has_Colour_Atlas_Pixels (Batch),
         "stale atlas metadata is ignored without glyph commands");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("stale atlas metadata", E);
   end;

   declare
      Prefix : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#11#, 2 => 16#22#, 3 => 16#33#, 4 => 16#44#);
      Image : constant RM.Image_Command :=
        (Raw_Format               => 32,
         Pixel_Width              => 2,
         Pixel_Height             => 1,
         Decoded_Byte_Length      => 8,
         Decoded_Row_Stride_Bytes => 8,
         Decoded_Source           => RM.Image_Decoded_Source_Raw_Base64,
         Decoded_Preview_Length   => Prefix'Length,
         Decoded_Preview_Bytes    => Prefix'Unchecked_Access,
         Preview_Decode_Complete  => True,
         Decode_Status            => RM.Image_Decode_Ok,
         others                   => <>);
   begin
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 8
         and then RM.Image_Decoded_Random_Access_Bytes (Image) = 4,
         "encoded image source extent is distinct from its accessible prefix");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 0, 3) = 16#44#
         and then RM.Image_Decoded_Row_Byte (Image, 0, 4) = 0,
         "encoded image byte access stops at the validated prefix");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("decoded source bounds", E);
   end;

   declare
   begin
      Assert
     (VS.Status_Label (VS.Ok) = "Submit build: Ok",
      "submit ok status label");
   Assert
     (VS.Status_Label (VS.Invalid_Frame) = "Submit build: Invalid Frame",
      "submit invalid status label");
   Assert
     (VS.Status_Label (VS.Capacity_Exceeded) =
        "Submit build: Capacity Exceeded",
      "submit capacity status label");
   Assert
     (VS.Status_Label (VS.Allocation_Failed)'Length <=
      VS.Max_Status_Label_Length,
      "submit status label should be bounded");
   Assert
     (VS.Texture_Source_Label (VS.Texture_None) = "none",
      "none texture source label");
   Assert
     (VS.Texture_Source_Label (VS.Texture_Text_Atlas) = "text-atlas",
      "text atlas texture source label");
   Assert
     (VS.Texture_Source_Label (VS.Texture_Image) = "image",
      "image texture source label");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Ok) = "",
      "ok image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Invalid_Byte) =
      " invalid-byte",
      "invalid-byte image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Trailing_Data) =
      " trailing-data",
      "trailing-data image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Preview_Truncated) =
      " truncated",
      "truncated image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Invalid_Data) =
      " invalid-data",
      "invalid-data image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Too_Large) =
      " too-large",
      "too-large image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Allocation_Failed) =
      " allocation-failed",
      "allocation-failed image decode suffix");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("status labels", E);
   end;

   declare
      type Item_Array is array (Positive range <>) of Natural;
      type Item_Array_Access is access all Item_Array;
      procedure Append is new Terminal.App.Bounded_Append
        (Natural, Item_Array, Item_Array_Access);
      procedure Free_Items is new Ada.Unchecked_Deallocation
        (Item_Array, Item_Array_Access);
      Items : Item_Array_Access := new Item_Array (5 .. 5);
      Count : Natural := 0;
      Appended : Boolean;
   begin
      Append (Items, Count, 17, Appended);
      Assert (Appended and then Count = 1 and then Items (5) = 17,
              "bounded append honors the array lower bound");
      Append (Items, Count, 23, Appended);
      Assert (not Appended and then Count = 1 and then Items (5) = 17,
              "bounded append reports exhaustion without partial mutation");
      Free_Items (Items);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("bounded append", E);
   end;

end Validation_Cases;

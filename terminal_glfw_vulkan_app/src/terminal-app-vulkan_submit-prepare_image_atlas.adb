separate (Terminal.App.Vulkan_Submit)
procedure Prepare_Image_Atlas
  (Frame : RM.Frame_Commands;
   Batch : in out Submission_Batch)
is
   Width  : Natural := 0;
   Height : Natural := 0;
   Max_Source_Dimension : Natural := 1;
   Scale_Divisor : Positive := 1;
   Packed : Boolean := False;

   function Scaled
     (Value : Positive; Divisor : Positive) return Positive is
     (1 + (Value - 1) / Divisor);

   function Try_Layout (Divisor : Positive) return Boolean is
      Candidate_Width  : Natural := 0;
      Candidate_Height : Natural := 0;
      Target_Width     : Positive;
      Target_Height    : Positive;
   begin
      for I in 1 .. Batch.Image_Atlas_Source_Total loop
         Target_Width := Scaled
           (Batch.Image_Atlas_Sources (I).Command.Pixel_Width, Divisor);
         Target_Height := Scaled
           (Batch.Image_Atlas_Sources (I).Command.Pixel_Height, Divisor);
         if Target_Width > Batch.Image_Atlas_Limit_Value.Dimension - 2
           or else Target_Height > Batch.Image_Atlas_Limit_Value.Dimension - 2
           or else Candidate_Height >
             Batch.Image_Atlas_Limit_Value.Dimension - (Target_Height + 2)
         then
            return False;
         end if;
         Batch.Image_Atlas_Sources (I).X := 1;
         Batch.Image_Atlas_Sources (I).Y := Candidate_Height + 1;
         Batch.Image_Atlas_Sources (I).Width := Target_Width;
         Batch.Image_Atlas_Sources (I).Height := Target_Height;
         Candidate_Width := Natural'Max (Candidate_Width, Target_Width + 2);
         Candidate_Height := Candidate_Height + Target_Height + 2;
      end loop;

      if Candidate_Width = 0
        or else Candidate_Height = 0
        or else Candidate_Width > Batch.Image_Atlas_Limit_Value.Bytes / 4
        or else Candidate_Height >
          Batch.Image_Atlas_Limit_Value.Bytes / (Candidate_Width * 4)
      then
         return False;
      end if;
      Width := Candidate_Width;
      Height := Candidate_Height;
      return True;
   end Try_Layout;
begin
   if Frame.Image_Count = 0
     or else Batch.Image_Atlas_Limit_Value.Dimension <= 2
   then
      return;
   end if;

   declare
      Required : constant Positive := Positive
        (Natural'Min (Frame.Image_Count, Max_Image_Atlas_Sources));
   begin
      if Batch.Image_Atlas_Sources = null
        or else Batch.Image_Atlas_Sources'Length < Required
      then
         declare
            Replacement : Image_Atlas_Source_Array_Access :=
              new Image_Atlas_Source_Array
                (1 .. Grown_Capacity
                  ((if Batch.Image_Atlas_Sources = null
                    then 0
                    else Batch.Image_Atlas_Sources'Length),
                   Required));
         begin
            if Batch.Image_Atlas_Sources /= null then
               Free_Image_Atlas_Sources (Batch.Image_Atlas_Sources);
            end if;
            Batch.Image_Atlas_Sources := Replacement;
         end;
      end if;
   end;
   for I in 1 .. Frame.Image_Count loop
      if Texture_Eligible (Frame.Images (I))
        and then Atlas_Source_Index (Batch, Frame.Images (I)) = 0
        and then Batch.Image_Atlas_Source_Total < Max_Image_Atlas_Sources
      then
         Batch.Image_Atlas_Source_Total := Batch.Image_Atlas_Source_Total + 1;
         Batch.Image_Atlas_Sources (Batch.Image_Atlas_Source_Total) :=
           (Command => Frame.Images (I), others => <>);
         Max_Source_Dimension := Natural'Max
           (Max_Source_Dimension,
            Natural'Max
              (Frame.Images (I).Pixel_Width,
               Frame.Images (I).Pixel_Height));
      end if;
   end loop;

   if Batch.Image_Atlas_Source_Total = 0 then
      return;
   end if;
   loop
      Packed := Try_Layout (Scale_Divisor);
      exit when Packed or else Scale_Divisor >= Max_Source_Dimension;
      if Scale_Divisor > Max_Source_Dimension / 2 then
         Scale_Divisor := Positive (Max_Source_Dimension);
      else
         Scale_Divisor := Scale_Divisor * 2;
      end if;
   end loop;
   if not Packed then
      Batch.Image_Atlas_Source_Total := 0;
      return;
   end if;

   Batch.Image_Atlas_W := Width;
   Batch.Image_Atlas_H := Height;
   Batch.Image_Atlas_Byte_Count := Width * Height * 4;
   declare
      Signature : Interfaces.Unsigned_64 := 16#CBF29CE484222325#;
      procedure Mix (Value : Interfaces.Unsigned_64) is
      begin
         Signature :=
           (Signature xor Value) * Interfaces.Unsigned_64'(16#100000001B3#);
      end Mix;
   begin
      Mix (Interfaces.Unsigned_64 (Width));
      Mix (Interfaces.Unsigned_64 (Height));
      Mix (Interfaces.Unsigned_64 (Batch.Image_Atlas_Source_Total));
      for I in 1 .. Batch.Image_Atlas_Source_Total loop
         declare
            Source : constant Image_Atlas_Source := Batch.Image_Atlas_Sources (I);
         begin
            Mix (Source.Command.Content_Serial);
            Mix (Interfaces.Unsigned_64 (Source.Command.Image_ID));
            Mix (Interfaces.Unsigned_64 (Source.Command.Pixel_Width));
            Mix (Interfaces.Unsigned_64 (Source.Command.Pixel_Height));
            Mix (Interfaces.Unsigned_64 (Source.Command.Raw_Format));
            Mix (Interfaces.Unsigned_64 (Source.Command.Decoded_Byte_Length));
            Mix (Interfaces.Unsigned_64 (Source.X));
            Mix (Interfaces.Unsigned_64 (Source.Y));
            Mix (Interfaces.Unsigned_64 (Source.Width));
            Mix (Interfaces.Unsigned_64 (Source.Height));
         end;
      end loop;
      Batch.Image_Atlas_Content_Signature :=
        (if Signature = 0 then 1 else Signature);
   end;
end Prepare_Image_Atlas;

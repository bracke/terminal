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
   Candidate_Count : Natural := 0;
   Candidate_Source_Bytes : Natural := 0;
   Cache_Matches : Boolean := True;
   type Candidate_Index_Array is
     array (Positive range 1 .. Max_Image_Atlas_Sources) of Positive;
   Candidate_Indices : Candidate_Index_Array := (others => 1);

   procedure Clear_Cache is
   begin
      if Batch.Image_Atlas_Sources /= null then
         for I in 1 .. Batch.Image_Atlas_Cached_Source_Total loop
            Release_Image_Source (Batch.Image_Atlas_Sources (I));
         end loop;
      end if;
      Batch.Image_Atlas_Cached_Source_Total := 0;
      Batch.Image_Atlas_Cached_Byte_Count := 0;
      Batch.Image_Atlas_Source_Total := 0;
   end Clear_Cache;

   function Same_Frame_Source
     (Left, Right : RM.Image_Command) return Boolean is
   begin
      if Left.Content_Serial /= 0 and then Right.Content_Serial /= 0 then
         return Left.Content_Serial = Right.Content_Serial
           and then Left.Image_ID = Right.Image_ID
           and then Same_Image_Layout (Left, Right);
      end if;
      return Same_Image_Source (Left, Right);
   end Same_Frame_Source;

   function Is_First_Source (Index : Positive) return Boolean is
   begin
      if Index = 1 then
         return True;
      end if;
      for Previous in 1 .. Index - 1 loop
         if Texture_Eligible (Frame.Images (Previous))
           and then Same_Frame_Source
             (Frame.Images (Previous), Frame.Images (Index))
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_First_Source;

   function Same_Cached_Content
     (Cached  : RM.Image_Command;
      Current : RM.Image_Command) return Boolean is
     (Cached.Content_Serial /= 0
      and then Current.Content_Serial /= 0
      and then Cached.Content_Serial = Current.Content_Serial
      and then Cached.Image_ID = Current.Image_ID
      and then Same_Image_Layout (Cached, Current));

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
      Clear_Cache;
      return;
   end if;

   for I in 1 .. Frame.Image_Count loop
      if Texture_Eligible (Frame.Images (I)) and then Is_First_Source (I) then
         declare
            Copy_Bytes : constant Natural :=
              Image_Source_Copy_Bytes (Frame.Images (I));
         begin
            --  The configured atlas limit bounds the resampled GPU image,
            --  not its source.  A large source may still be reduced to fit,
            --  but all retained source copies together remain globally
            --  bounded.
            if Copy_Bytes <=
              Max_Image_Atlas_Bytes - Candidate_Source_Bytes
            then
               Candidate_Count := Candidate_Count + 1;
               Candidate_Indices (Candidate_Count) := I;
               Candidate_Source_Bytes := Candidate_Source_Bytes + Copy_Bytes;
               exit when Candidate_Count = Max_Image_Atlas_Sources;
            end if;
         end;
      end if;
   end loop;
   if Candidate_Count = 0 then
      Clear_Cache;
      return;
   end if;

   declare
      Required : constant Positive := Positive (Candidate_Count);
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
            Batch.Image_Atlas_Cached_Source_Total := 0;
            Batch.Image_Atlas_Cached_Byte_Count := 0;
         end;
      end if;
   end;

   Cache_Matches :=
     Batch.Image_Atlas_Cached_Source_Total = Candidate_Count
     and then Batch.Image_Atlas_Cached_Byte_Count = Candidate_Source_Bytes;
   for Candidate in 1 .. Candidate_Count loop
      if Cache_Matches
        and then not Same_Cached_Content
          (Batch.Image_Atlas_Sources (Candidate).Command,
           Frame.Images (Candidate_Indices (Candidate)))
      then
         Cache_Matches := False;
      end if;
   end loop;

   if not Cache_Matches then
      Clear_Cache;
   end if;

   for Candidate in 1 .. Candidate_Count loop
      declare
         Image : RM.Image_Command renames
           Frame.Images (Candidate_Indices (Candidate));
      begin
         if not Cache_Matches then
            Own_Image_Source
              (Image, Batch.Image_Atlas_Sources (Candidate));
         else
            Batch.Image_Atlas_Sources (Candidate).Input_Decoded :=
              Image.Decoded_Bytes;
            Batch.Image_Atlas_Sources (Candidate).Input_Encoded :=
              Image.Encoded_Source_Bytes;
         end if;
         Max_Source_Dimension := Natural'Max
           (Max_Source_Dimension,
            Natural'Max (Image.Pixel_Width, Image.Pixel_Height));
      end;
   end loop;

   Batch.Image_Atlas_Source_Total := Candidate_Count;
   Batch.Image_Atlas_Cached_Source_Total := Candidate_Count;
   Batch.Image_Atlas_Cached_Byte_Count := Candidate_Source_Bytes;

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
      Cacheable : Boolean := True;
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
            Source : Image_Atlas_Source renames Batch.Image_Atlas_Sources (I);
         begin
            if Source.Command.Content_Serial = 0 then
               Cacheable := False;
            end if;
            Mix (Source.Command.Content_Serial);
            Mix (Interfaces.Unsigned_64 (Source.Command.Image_ID));
            Mix (Interfaces.Unsigned_64 (Source.Command.Pixel_Width));
            Mix (Interfaces.Unsigned_64 (Source.Command.Pixel_Height));
            Mix (Interfaces.Unsigned_64 (Source.Command.Raw_Format));
            Mix (Interfaces.Unsigned_64
              (RM.Image_Decoded_Source_Kind'Pos
                 (Source.Command.Decoded_Source)));
            Mix (Interfaces.Unsigned_64
              (Source.Command.Decoded_Row_Stride_Bytes));
            Mix (Interfaces.Unsigned_64 (Source.Command.Decoded_Byte_Length));
            Mix (Interfaces.Unsigned_64
              (Source.Command.Encoded_Source_Length));
            Mix (Interfaces.Unsigned_64 (Source.X));
            Mix (Interfaces.Unsigned_64 (Source.Y));
            Mix (Interfaces.Unsigned_64 (Source.Width));
            Mix (Interfaces.Unsigned_64 (Source.Height));
         end;
      end loop;
      Batch.Image_Atlas_Content_Signature :=
        (if not Cacheable then 0
         elsif Signature = 0 then 1
         else Signature);
   end;
end Prepare_Image_Atlas;

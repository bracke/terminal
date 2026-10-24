with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces;

package body Terminal.App.Image_Rendering is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Image_Decode.Status;
   use type Terminal.App.Image_Media.Decode_Limit_Kind;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Trimmed_Unsigned (Value : Interfaces.Unsigned_64) return String is
     (Ada.Strings.Fixed.Trim
        (Interfaces.Unsigned_64'Image (Value), Ada.Strings.Left));

   procedure Clear (Diagnostics : out Media_Diagnostics) is
   begin
      Diagnostics := (others => <>);
   end Clear;

   procedure Capture
     (Diagnostics : out Media_Diagnostics;
      Image       : Terminal.App.Image_Media.Decoded_Image;
      Status      : Terminal.App.Image_Decode.Status)
   is
   begin
      Diagnostics :=
        (Attempted => True,
         Status => Status,
         Error => Image.Diagnostic,
         Adapter_Buffer_Bytes => Image.Adapter_Buffer_Bytes,
         Decoder_Configured_Bytes => Image.Decoder_Configured_Bytes,
         Warning_Count => Image.Warning_Count,
         First_Warning => Image.First_Warning);
   end Capture;

   procedure Set_Status
     (Diagnostics : out Media_Diagnostics;
      Status      : Terminal.App.Image_Decode.Status)
   is
   begin
      Diagnostics :=
        (Attempted => True,
         Status    => Status,
         others    => <>);
   end Set_Status;

   function Animation_Capacity_Available
     (Retained : Natural;
      Incoming : Natural;
      Limit    : Natural) return Boolean
   is
   begin
      return Incoming > 0
        and then Retained <= Limit
        and then Incoming - 1 <= Limit - Retained;
   end Animation_Capacity_Available;

   function Status_Label (Diagnostics : Media_Diagnostics) return String is
      package IM renames Terminal.App.Image_Media;

      function Detail (Item : IM.Decode_Diagnostic) return String is
      begin
         return
           IM.Diagnostic_Identifier (Item)
           & " source=" & Trimmed_Unsigned (Item.Source_Offset)
           & (if Item.Has_Opcode
              then " opcode=" & Trimmed_Natural (Item.Opcode)
              else "")
           & (if Item.Expected /= 0 or else Item.Actual /= 0
              then
                " expected=" & Trimmed_Unsigned (Item.Expected)
                & " actual=" & Trimmed_Unsigned (Item.Actual)
              else "")
           & (if Item.Limit /= IM.No_Limit
              then
                " limit=" & Ada.Strings.Fixed.Trim
                  (IM.Decode_Limit_Kind'Image (Item.Limit), Ada.Strings.Left)
              else "")
           & (if Item.Has_Underlying_Code
              then
                " code=" & Ada.Strings.Fixed.Trim
                  (Long_Long_Integer'Image (Item.Underlying_Code),
                   Ada.Strings.Left)
              else "");
      end Detail;

      function Full_Label return String is
      begin
         if Diagnostics.Error.Present then
            return "media error=" & Detail (Diagnostics.Error);
         elsif Diagnostics.Warning_Count > 0
           and then Diagnostics.First_Warning.Present
         then
            return
              "media warning=" & Detail (Diagnostics.First_Warning)
              & " count=" & Trimmed_Natural (Diagnostics.Warning_Count)
              & " adapter_buffers="
              & Trimmed_Natural (Diagnostics.Adapter_Buffer_Bytes)
              & " decoder_configured="
              & Trimmed_Natural (Diagnostics.Decoder_Configured_Bytes);
         elsif Diagnostics.Attempted
           and then Diagnostics.Status /=
             Terminal.App.Image_Decode.Decode_Ok
         then
            return
              "media" & Terminal.App.Image_Decode.Suffix (Diagnostics.Status);
         elsif Diagnostics.Adapter_Buffer_Bytes > 0
           or else Diagnostics.Decoder_Configured_Bytes > 0
         then
            return
              "media memory adapter_buffers="
              & Trimmed_Natural (Diagnostics.Adapter_Buffer_Bytes)
              & " decoder_configured="
              & Trimmed_Natural (Diagnostics.Decoder_Configured_Bytes);
         else
            return "";
         end if;
      end Full_Label;

      Label : constant String := Full_Label;
   begin
      return
        (if Label'Length <= Max_Status_Label_Length
         then Label
         else Label (Label'First .. Label'First + Max_Status_Label_Length - 1));
   end Status_Label;
end Terminal.App.Image_Rendering;

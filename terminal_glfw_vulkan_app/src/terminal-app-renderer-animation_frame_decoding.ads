with Terminal.App.Graphics;
with Terminal.App.Owned_Image_Data;

private package Terminal.App.Renderer.Animation_Frame_Decoding is
   type Result is limited record
      Data              : Terminal.App.Graphics.Graphics_Data_Preview;
      Copy_Failed       : Boolean := False;
      Quota_Failed      : Boolean := False;
      Allocation_Failed : Boolean := False;
   end record;

   procedure Decode
     (Header                            : Terminal.App.Graphics.Graphics_Header;
      Text                              : String;
      Per_Image_Bytes                   : Positive;
      Pixel_Dimension                   : Positive;
      Allow_Unknown_Compressed_PNG_Size : Boolean;
      Output                            : in out Result);
end Terminal.App.Renderer.Animation_Frame_Decoding;

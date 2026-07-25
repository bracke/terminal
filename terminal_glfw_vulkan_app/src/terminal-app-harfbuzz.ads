with System;

with Terminal.App.Render_Model;

package Terminal.App.HarfBuzz is
   type Font_Face is limited private;

   type Load_Status is
     (Loaded,
      Invalid_Path,
      Load_Failed);

   type Shape_Status is
     (Shaped,
      Not_Loaded,
      Invalid_Run,
      Buffer_Overflow,
      Shape_Failed);

   procedure Load
     (Face        : in out Font_Face;
      Path        : String;
      Pixel_Size  : Positive;
      Status      : out Load_Status);

   procedure Reset (Face : in out Font_Face);

   function Is_Loaded (Face : Font_Face) return Boolean;

   procedure Shape
     (Face   : Font_Face;
      Font_Index : Natural;
      Run    : in out Terminal.App.Render_Model.Text_Run_Command;
      Status : out Shape_Status);

private
   type Font_Face is limited record
      Blob       : System.Address := System.Null_Address;
      Face       : System.Address := System.Null_Address;
      Font       : System.Address := System.Null_Address;
      Pixel_Size : Positive := 16;
   end record;
end Terminal.App.HarfBuzz;

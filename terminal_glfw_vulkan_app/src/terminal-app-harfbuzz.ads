with Ada.Finalization;
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
     (Face   : in out Font_Face;
      Path   : String;
      Status : out Load_Status);

   procedure Reset (Face : in out Font_Face);

   procedure Configure
     (Face       : in out Font_Face;
      Features   : String;
      Variations : String;
      Accepted   : out Boolean);

   function Is_Loaded (Face : Font_Face) return Boolean;

   procedure Shape
     (Face   : Font_Face;
      Font_Index : Natural;
      Run    : in out Terminal.App.Render_Model.Text_Run_Command;
      Status : out Shape_Status);

private
   Max_Configuration_Length : constant := 512;
   type Font_Face is new Ada.Finalization.Limited_Controlled with record
      Blob : System.Address := System.Null_Address;
      Face : System.Address := System.Null_Address;
      Font : System.Address := System.Null_Address;
      Feature_Length : Natural range 0 .. Max_Configuration_Length := 0;
      Feature_Text : String (1 .. Max_Configuration_Length) :=
        (others => ASCII.NUL);
   end record;
   overriding procedure Finalize (Face : in out Font_Face);
end Terminal.App.HarfBuzz;

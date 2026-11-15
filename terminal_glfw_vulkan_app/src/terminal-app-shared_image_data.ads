with Ada.Finalization;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;

--  Reference-counted immutable bytes for snapshots that may outlive the
--  container from which they were obtained.
private package Terminal.App.Shared_Image_Data is
   package RM renames Terminal.App.Render_Model;

   type Handle is new Ada.Finalization.Controlled with private;

   procedure Set
     (Item   : in out Handle;
      Source : RM.Image_Data_View;
      Length : Natural);
   procedure Reset (Item : in out Handle);
   function View (Item : Handle) return RM.Image_Data_View;

   overriding procedure Adjust (Item : in out Handle);
   overriding procedure Finalize (Item : in out Handle);

private
   type Image_Data_Access is access all Terminal.Common.Bytes.Byte_Array;
   protected type Reference_Counter is
      procedure Acquire;
      procedure Release (Is_Last : out Boolean);
   private
      Count : Natural := 1;
   end Reference_Counter;
   type Control_Block;
   type Control_Access is access Control_Block;
   type Control_Block is record
      References : Reference_Counter;
      Data       : Image_Data_Access := null;
   end record;
   type Handle is new Ada.Finalization.Controlled with record
      Control : Control_Access := null;
   end record;
end Terminal.App.Shared_Image_Data;

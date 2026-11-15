with Terminal.App.Image_Data;

--  Test-only bridge for legacy fixtures that deliberately exercise transfer
--  from manually allocated buffers.
package Terminal.App.Owned_Image_Data.Unsafe is
   procedure Adopt
     (Item : in out Owner;
      Data : in out Terminal.App.Image_Data.Image_Data_Access);
   procedure Take
     (Item : in out Owner;
      Data : out Terminal.App.Image_Data.Image_Data_Access);
end Terminal.App.Owned_Image_Data.Unsafe;

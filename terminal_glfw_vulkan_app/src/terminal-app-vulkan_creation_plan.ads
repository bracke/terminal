with Interfaces;

package Terminal.App.Vulkan_Creation_Plan is
   type Queue_Plan is record
      Graphics_Family               : Interfaces.Unsigned_32;
      Present_Family                : Interfaces.Unsigned_32;
      Device_Queue_Info_Count       : Interfaces.Unsigned_32;
      Swapchain_Queue_Family_Count  : Interfaces.Unsigned_32;
      Concurrent_Sharing            : Boolean;
   end record;

   function Build_Queue_Plan
     (Graphics_Family : Natural;
      Present_Family  : Natural) return Queue_Plan;

   function Extent_Is_Valid
     (Width, Height     : Interfaces.Unsigned_32;
      Maximum_Dimension : Positive) return Boolean;
end Terminal.App.Vulkan_Creation_Plan;

package Terminal.App.Vulkan_Retirement is
   type Fence_Outcome is
     (Fence_Ready, Fence_In_Flight, Fence_Device_Lost, Fence_Failed);
   type Retirement_Outcome is
     (Retired, Still_In_Flight, Device_Lost, Cleanup_Failed, Fence_Failed);

   function Evaluate
     (Fence             : Fence_Outcome;
      Cleanup_Succeeded : Boolean) return Retirement_Outcome;
end Terminal.App.Vulkan_Retirement;

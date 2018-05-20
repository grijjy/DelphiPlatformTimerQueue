# Using the Apple's Grand Central Dispatch and Android's ScheduledThreadPoolExecutor for Delphi timers
You are probably already familiar with the NSTimer on iOS/macOS and JTimer on Android for timer events.  In addition to the basic timers, most operating systems offer a more advanced threaded schedule event API.  On Android there is the [ScheduledThreadPoolExecutor](https://developer.android.com/reference/java/util/concurrent/ScheduledThreadPoolExecutor) which allows you to launch a Runnable at a specific time period.  On iOS/macOS the operating system includes the [Grand Central Dispatch](https://developer.apple.com/documentation/DISPATCH) (GCD) which allows you to schedule events.  On Windows we have the CreateTimerQueueTimer APIs for a similar purpose.

In this article we will show how you can use these APIs on mobile, desktop and server platforms in Delphi in a unified manner and receive OnTimer() events that you are already familiar with.

Of course, it is possible to create your own thread pool and simulate timer events.  However, the operating system already has it's own kernel-managed thread pool for scheduled events.  By leveraging these APIs you can share thread resources across all the processes on the device and this is especially important for platforms where it is not advisable to create numerous threads.  Unlike a regular timer object, you can run more than one scheduled timer from the same timer object, thereby avoiding allocating numerous individual timer objects.  Timer events can share threads from the OS pool if the event durations don't exceed the interval rate and more.

Also, there are situations where you need a scheduled timer but you don't have a main application loop to fire events or a window, such as library modules, server logic, etc.  You can go through the effort of creating hidden windows of course, but the OS based scheduled event APIs don't have this limitation.

- On Android we use the JScheduledThreadPoolExecutor class and JRunnable to allow the OS to manage the thread pool
- On macOS/iOS we use the Grand Central Dispatch and allow the OS the OS to manage the thread pool
- On Windows we use the CreateTimerQueueTimer() API to allow the OS/kernel to manage the thread pool and callback.
- On Linux64 we use Epoll and the TimerFd capability to signal timer events along with our own managed thread pool

For more information about us, our support and services visit the [Grijjy homepage](http://www.grijjy.com) or the [Grijjy developers blog](http://blog.grijjy.com).

The example contained here depends upon part of our [Grijjy Foundation library](https://github.com/grijjy/GrijjyFoundation).

The source code and related example repository is hosted on GitHub at [https://github.com/grijjy/DelphiPlatformTimerQueue](https://github.com/grijjy/DelphiPlatformTimerQueue).

## Grand Central Dispatch on iOS and macOS
On iOS and macOS we have a unified approach called the [Grand Central Dispatch](https://developer.apple.com/documentation/DISPATCH).  The GCD provides numerous capabilities to help developers with parallel applications on Apple devices.  Apple recommends this approach for threading events so that all applications on a given device can better share system resources.

To create a event that repeats at a specified interval, you need to use 5 core APIs of the GCD:
1. Use the `dispatch_get_global_queue()` API to create a global queue that you will share with all your timers.
2. Call `dispatch_source_create()` to create a timer that is associated with the queue.
3. Call `dispatch_source_set_timer()` to specify the interval and accuracy of your timer.
4. Call `dispatch_source_set_event_handler()` to specify the callback for the event.
5. Finally call `dispatch_resume()` to start your timer.

The APIs are straightforward to use, except for a couple of things.  First, Delphi is currently missing some of these constants and exports, so we include a conversion called Macapi.Gcd.pas in our Grijjy Repository.

Secondly, and far more difficult is the usage of the `dispatch_source_set_event_handler()` API which uses an ObjectiveC block for the callback.  There are numerous approaches to using ObjC blocks in Delphi code, but we prefer a method implemented by the team over at Tamosoft.  We include a unit to simplify those ObjC blocks in Delphi based upon their [blog article](https://habr.com/post/325204/).  Their methodology makes the usage of an ObjC block in Delphi as simple as the following example,

```Delphi
TObjCBlock.CreateBlockWithProcedure(
  procedure(p1: NSInteger; p2: Pointer)
  begin
    if Assigned(FOnTimer) then
      FOnTimer(Self);
  end));
```
Here our anonymous method runs when the block is called which in turn calls our timer event.

We only need to create a single global queue for all the GCD timers, so in Delphi we could use a simple method to check for the existance of the global queue, and create one if required.  For example,
```Delphi
function GetGlobalQueue: dispatch_queue_t;
begin
  if FGlobalQueue = nil then
    FGlobalQueue := dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  Result := FGlobalQueue;
end;
```

Then to finally put it all together we create our timer using `DISPATCH_SOURCE_TYPE_TIMER` and use the `dispatch_source_set_timer` API to specify both the startup delay and the interval.  We could choose to have the timer fire immediately upon startup, but it is customary to have the first event after the first interval, so we provide a delay which matches the interval.  If you are concerned with accuracy of the timer, the GCD API also provides an accuracy leeway.

Then we call `dispatch_source_set_event_handler` with our OnTimer() event as an ObjC block followed by `dispatch_resume` to start the timer.

```Delphi
  FDispatchTimer := dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, FTimerQueue.GlobalQueue);
  if Assigned(FDispatchTimer) then
  begin
    dispatch_source_set_timer(FDispatchTimer,
      dispatch_time(DISPATCH_TIME_NOW, AInterval * NSEC_PER_MSEC), // Start delay
      AInterval * NSEC_PER_MSEC, // Interval
      0); // Leeway

    dispatch_source_set_event_handler(FDispatchTimer,
      TObjCBlock.CreateBlockWithProcedure(
        procedure(p1: NSInteger; p2: Pointer)
        begin
          if Assigned(FOnTimer) then
            FOnTimer(Self);
        end));

    dispatch_resume(FDispatchTimer);
```

To change the interval rate of the timer, while the timer is operating the GCD you simply call the `dispatch_source_set_timer` method again:

```Delphi
dispatch_source_set_timer(FDispatchTimer,
  dispatch_time(DISPATCH_TIME_NOW, AInterval * NSEC_PER_MSEC), AInterval * NSEC_PER_MSEC, 0);
```  

## ScheduledThreadPoolExecutor for Android
On Android we have a class called the ScheduledThreadPoolExecutor that allows us to create timers using an API called `scheduleAtFixedRate`.  

To create a ScheduledThreadPoolExecutor we simple define one and initialize it.  During the initialization we must specify the total maximum threads in the pool.
 
```Delphi
var
  ScheduledThreadPoolExecutor: JScheduledThreadPoolExecutor;

ScheduledThreadPoolExecutor := _TJScheduledThreadPoolExecutor.JavaClass.init(ANDROID_THREAD_POOL_SIZE);

```
The ScheduledThreadPoolExecutor expects to call a Runnable object, so to use this API we must first create a Runnable object. The following example shows a simple example of how this is done:
```Delphi
var
  FRunnable: JRunnable;

type
  TAndroidRunnable = class(TJavaLocal, JRunnable)
  private
    FTimer: TgoTimer;
  public
    constructor Create(const ATimer: TgoTimer);
    procedure run; cdecl;
  end;

FRunnable := TAndroidRunnable.Create(Self);
```
Then to startup your timer you only need to call the `scheduleAtFixedRate` API.

```Delphi
FScheduledFuture := ScheduledThreadPoolExecutor.scheduleAtFixedRate(FRunnable, AInterval, AInterval, TJTimeUnit.JavaClass.MILLISECONDS);
```
A few things to note here.  First off, just like the Apple GCD, you are passing both an initial delay and an interval so the timer events start at the first interval.  More importantly we are returning a ScheduledFuture object here.  The ScheduledFuture allows you to interact with your timer.  Delphi's import for the `scheduleAtFixedRate` API does not return a ScheduledFuture, so in our implementation we created another version of the import. 

To change the interval rate of a running timer you only need to cancel the existing timer, and call `scheduleAtFixedRate` again, for example:

```Delphi
FScheduledFuture.cancel(True);
FScheduledFuture := ScheduledThreadPoolExecutor.scheduleAtFixedRate(FRunnable, AInterval, AInterval, TJTimeUnit.JavaClass.MILLISECONDS);
```
## Windows CreateTimerQueueTimer and Linux EPoll
On Windows we have an API called `CreateTimerQueueTimer` to perform a substantially similar thread based timer.  On Linux we have a concept of timer file descriptors which we can use with the Epoll APIs and our own thread pool to time events.  

Since we covered these concepts in detail for Windows and Linux timers in a [recent article](https://blog.grijjy.com/2017/04/20/cross-platform-timer-queues-for-windows-and-linux/), I won't go into detail in this article.  Please refer to that article if your interest is primarily Windows or Linux.  

However, we have merged those concepts into a single unit and a unified class so that the TgoTimer() related unit and classes work the same on all platforms including iOS, macOS, Android, Windows and Linux.  As a developer you can simply use the class and setup your OnTimer() events and the interface is identical.

## Considerations
Please keep in mind that there are some differences between platforms in how they handle overlapped timer events (when your total callback time exceeds the interval rate).  Some of the platform specific APIs will simply issue a new thread and timer event at the interval rate while others will wait until you return.

If you don't want overlapping events, then one way to handle this is to check in your own OnTimer() event if you are already executing and exit.  You could use an Atomic operation to check or a TryLock condition.

Of course you may want your timer events to overlap, especially if your timer event is time sensitive.  As a developer you have to consider your scenario.

Also Delphi native timers are designed to be synchronized with the main application thread.  This allows you to update the user interface from your timer event.  Your normal Delphi timer will be blocked in cases that the operation takes longer than the interval and this is sometimes desired behavior.

If you want to synchronize the TgoTimer event with the application thread, you could simply call TThread.Synchronize in your OnTimer() event,

```Delphi
TThread.Synchronize(nil,
  procedure
  begin
	// Update the user interface
  end);
``` 
We do this in our Firemonkey example so that we can update a Memo component from our OnTimer() event.

## Examples and source code
In our GitHub repository we have included both a cross-platform Firemonkey based example that runs on all platforms to demonstrate timer basics and a console application for Windows and Linux.

The example program at [https://github.com/grijjy/DelphiPlatformTimerQueue](https://github.com/grijjy/DelphiPlatformTimerQueue).

## Conclusion
In the end it's not a lot of code to unify timers on all platforms, but it took us a while to figure out these nuances on mobile platforms.  We hope you find this article helpful for your efforts and a useful addition to your application.  We have utilized threaded timers for silent reconnection logic, heartbeat logic on servers and more.  

For more information about us, our support and services visit the [Grijjy homepage](http://www.grijjy.com) or the [Grijjy developers blog](http://blog.grijjy.com).

The base classes described herein are part of our [Grijjy Foundation library](https://github.com/grijjy/GrijjyFoundation).  
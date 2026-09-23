# Save TikTok workouts from the share sheet

Yarms uses a personal Shortcut so it can be installed with a free Apple Personal Team. Set up **Save to Yarms** once on each iPhone. Afterward, sharing a TikTok link does not require copying it, opening Yarms, or typing.

1. Install and open Yarms once. In the **Shortcuts** app, create a new shortcut named **Save to Yarms**.
2. In the shortcut's Details, turn on **Show in Share Sheet** and allow **URLs** and **Text** as input types.
3. Add the Yarms action **Save TikTok Workout**. Set its **Shared TikTok Link** field to **Shortcut Input**.
4. Save the shortcut. In TikTok, open a workout video, tap **Share**, and select **Save to Yarms**. You may need **More** to find it initially.
5. Reopen Yarms to see the saved workout. The action saves the link first; Yarms fetches available title, creator, and thumbnail when it opens.

TikTok may supply a URL or text around the URL. Yarms scans the shared text for a valid TikTok video link and reports an error if none is present. The app's **Paste link** action remains available. Apple documents [running a Shortcut from another app's share sheet](https://support.apple.com/guide/shortcuts/understanding-input-types-apd7644168e1/ios).

Free Personal Team builds have short-lived provisioning profiles and need periodic rebuilds in Xcode. Apple currently documents a seven-day profile lifetime and a limit of three devices and three apps per device for personal teams; each person using Yarms needs the app installed on their own iPhone. See [Apple's account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).

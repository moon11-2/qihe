<script setup lang="ts">
import { onLaunch, onShow, onHide } from "@dcloudio/uni-app";
onLaunch(() => {
  console.log("Qihe Launch");
});
onShow(() => {
  console.log("Qihe Show");
});
onHide(() => {
  console.log("Qihe Hide");
});
</script>
<style>
page {
  min-height: 100%;
  background: #f6f9ff;
  color: #111827;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC",
    "Helvetica Neue", Arial, sans-serif;
}

view,
text,
button,
textarea,
input {
  box-sizing: border-box;
}

button {
  padding: 0;
  margin: 0;
  background: transparent;
  border: 0;
  line-height: 1;
}

button::after,
uni-button::after {
  border: 0;
}

uni-button {
  padding: 0;
  margin: 0;
  background: transparent;
  border: 0;
  line-height: 1;
}
</style>

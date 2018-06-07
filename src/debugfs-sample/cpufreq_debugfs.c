#include <linux/module.h>
#include <linux/debugfs.h>
#include <linux/types.h>
#include <linux/seq_file.h>
#include <linux/delay.h>
#include <asm/cpu-info.h>
#include <asm/time.h>

#include <linux/init.h>
#include <linux/kernel.h>
#include <asm/gic.h>

#include <linux/cpufreq.h>
#include <linux/kernel_stat.h>
#include <linux/tick.h>
#include <linux/cpu.h>

#include <linux/timer.h>

//get cpu_clk
#include <linux/clocksource.h>
#include <linux/clk-private.h>

//kmalloc/kfree
#include <linux/slab.h>

static struct mutex g_mutex;

static struct dentry *entry;

static int cpufreq_show(struct seq_file *m, void *v)
{
	seq_printf(m,"Set cpu frequency in SF16A18 board.\n");

	return 0;
}

static int cpufreq_open(struct inode *inode, struct file *file)
{
	return single_open(file, cpufreq_show, NULL);
}

#ifdef CLKEVENT_TEST
static struct timer_list timer;
static char* msg = "hello world";
static int64_t counter = 0;

struct hrtimer m_timer;

static void print_func(unsigned long lparam){
	char* str = (char*)lparam;
	printk("%s counter=%lld\n",str,counter);
	mod_timer(&timer, jiffies + 2*HZ);
}

static enum hrtimer_restart vibrator_timer_func(struct hrtimer *timer)
{
	hrtimer_forward_now(&m_timer,ktime_set(0, 1000000));
	counter++;
	return HRTIMER_RESTART;
}

void test_timer(void)
{
	init_timer(&timer);
	timer.expires = jiffies + 2*HZ;
	timer.function = print_func;
	timer.data = (unsigned long) msg;
	add_timer(&timer);
	//add high res timer
	hrtimer_init(&m_timer, CLOCK_MONOTONIC, HRTIMER_MODE_REL_PINNED);
	m_timer.function = vibrator_timer_func;
	//set to 10 us
	hrtimer_start(&m_timer,ktime_set(0, 1000000),HRTIMER_MODE_REL_PINNED);
}
#endif

extern void gic_clocksource_update(unsigned int frequency);
static unsigned int old_cpu_freq;

static ssize_t cpufreq_read(struct file *file, char __user *buffer,
							size_t count, loff_t *f_ops)
{
	char *buf = kmalloc(count, GFP_KERNEL);
	int n = 0;

	if(!buf)
		return -ENOMEM;

	if(*f_ops > 0) {
		kfree(buf);
		return 0;
	}

	n = snprintf(buf, count, "cpu frequency now is %d", old_cpu_freq);
	//printk("n is %d, buf is %s\n", n, buf);

	if(copy_to_user(buffer, buf, n))
		n = -EFAULT;

	*f_ops += n;
	kfree(buf);

	return n;
}

static enum hrtimer_restart ht1_func(struct hrtimer *timer)
{
	printk("ht1 callback func\n");
	return HRTIMER_NORESTART;
}

struct hrtimer ht1;
#include <linux/smp.h>
extern void console_unlock(void);
extern int console_trylock(void);
void testprintk(void *a)
{
#if 0
	int i = 0;
	for (; i < 100000000; i++) {
		printk("%s now running on cpu%d\n", __func__, raw_smp_processor_id());
		while (!console_trylock());
		console_unlock();
	}
#else
	printk("%s now running on cpu%d\n", __func__, raw_smp_processor_id());
#endif
	return;
}
static ssize_t cpufreq_write(struct file *file, const char __user *buffer,
						size_t count, loff_t *f_ops)
{
	unsigned int val;

	mutex_lock(&g_mutex);

	sscanf(buffer, "%u", &val);
	if (val) {
		smp_call_function_single((raw_smp_processor_id() + 1) % 4, testprintk, NULL, 0);
	}

	mutex_unlock(&g_mutex);

	return count;
}

static struct file_operations cpufreq_ops = {
	.owner		= THIS_MODULE,
	.open		= cpufreq_open,
	.read		= cpufreq_read,
	.write		= cpufreq_write,
	.release	= seq_release,
	.llseek		= seq_lseek,
};

static int __init cpu_freq_init(void)
{
	struct device_node *node;
	struct clk *sf_cpu_clk;

	mutex_init(&g_mutex);

	node = of_find_compatible_node(NULL, NULL, "siflower,sfax8-syscon");

#ifdef USE_SYSCON
	if(node)
		regmap_base = syscon_node_to_regmap(node);

	if(IS_ERR(regmap_base)) {
		pr_err("can't get syscon base.\n");
		return 0;
	}
#endif

	node = of_find_compatible_node(NULL, NULL, "siflower,sfax8-gic");

	if(node)
		sf_cpu_clk = of_clk_get(node,0);

	if(IS_ERR(sf_cpu_clk)) {
		printk("Can't get cpu clock!\n");
		return 0;
	}

	old_cpu_freq = clk_get_rate(sf_cpu_clk);

	entry = debugfs_create_file("cpu-freq", 0644, NULL, NULL, &cpufreq_ops);

	hrtimer_init(&ht1, CLOCK_MONOTONIC, HRTIMER_MODE_REL_PINNED);
	ht1.function = ht1_func;

	return 0;
}

static void __exit cpu_freq_exit(void)
{
	debugfs_remove(entry);
#ifdef CLKEVENT_TEST
	del_timer(&timer);
#endif
	mutex_destroy(&g_mutex);

	return;
}

module_init(cpu_freq_init);
module_exit(cpu_freq_exit);
MODULE_LICENSE("GPL");

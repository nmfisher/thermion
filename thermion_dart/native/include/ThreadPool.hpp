/*
 * This file is licensed under the zlib/libpng license, included in this
 * distribution in the file COPYING.
 */

#include <future>
#include <thread>
#include <deque>
#include <vector>
#include <utility>
#include <chrono>
#include <functional>
#include <type_traits>

#ifndef _THREADPOOL_HPP
#define _THREADPOOL_HPP

namespace thermion_flutter {

class ThreadPool {
	std::vector<std::thread> pool;
	bool stop;

	std::mutex access;
	std::condition_variable cond;
	std::deque<std::function<void()>> tasks;

public:
	explicit ThreadPool(int nr = 1) : stop(false) {
		while(nr-->0) {
			add_worker();
		}
	}
	~ThreadPool() {
		stop = true;
		for(std::thread &t : pool) {
			t.join();
		}
		pool.clear();
	}

	template<class Rt>
	auto add_task(std::packaged_task<Rt()>& pt) -> std::future<Rt> {
		std::unique_lock<std::mutex> lock(access);

		auto ret = pt.get_future();
		tasks.push_back([pt=std::make_shared<std::packaged_task<Rt()>>(std::move(pt))]{ (*pt)();});

		cond.notify_one();

		return ret;
	}

private:
	void add_worker() {
		std::thread t([this]() {
			while(!stop || tasks.size() > 0) {
				std::function<void()> task;
				{
					std::unique_lock<std::mutex> lock(access);
					if(tasks.empty()) {
						cond.wait_for(lock, std::chrono::duration<int, std::milli>(5));
						continue;
					}
					task = std::move(tasks.front());
					tasks.pop_front();
				}
				task();
			}
		});
		pool.push_back(std::move(t));
	}
};

}

#endif//_THREADPOOL_HPP

// vim: syntax=cpp11